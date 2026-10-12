# Operations Runbook

Owner: on-call engineer (rotation in the team calendar). Alerts arrive via the
`puzzlehub-<env>-alerts` SNS topic.

## Environments

| Env | Purpose | Deploys | Data |
|---|---|---|---|
| local | dev | `make up` | docker volume |
| CI | quality gates | every PR | Testcontainers (ephemeral) |
| staging | release candidates | automatic on `main` | synthetic, separate account/credentials |
| production | users | manual approval (`production` environment) | real; least-privilege access |

## Deploy (backend)

1. Merge to `main` → `deploy-backend` runs tests, builds an ARM64 image tagged with the
   commit SHA, deploys to staging and runs `scripts/smoke-test.sh`.
2. A reviewer approves the `production` environment. The **same image digest** is
   copied to the prod repository and rolled out (min healthy 100%, max 200%).
3. ECS waits for steady state; the deployment circuit breaker rolls back automatically
   if new tasks fail health checks.
4. Watch the CloudWatch dashboard `puzzlehub-prod` for 30 minutes: 5xx rate, p95 latency,
   unhealthy hosts, DB connections.

Database migrations run at application start (Flyway). They must be backward compatible
with the previous release (expand/contract), so a rollback never requires a schema revert.

## Rollback

* **Automatic:** circuit breaker → previous task definition.
* **Manual:**
  ```bash
  aws ecs describe-services --cluster puzzlehub-prod --services api \
    --query 'services[0].deployments'
  aws ecs update-service --cluster puzzlehub-prod --service api \
    --task-definition puzzlehub-prod-api:<previous-revision>
  ```
* **Bad migration:** do not hand-edit. Ship a forward fix migration. If data was
  corrupted, follow the restore procedure into a *new* instance and reconcile.
* **App release:** halt the staged rollout in Play Console (Release → Halt rollout), then
  ship a hotfix with a higher version code. Play cannot roll back an installed version.

## Incident severities

| Sev | Examples | First response | Comms |
|---|---|---|---|
| SEV-1 | data exposure, widespread outage, corrupted scores, daily challenge broken for most users | declare incident, stop rollouts, protect data, preserve logs, page owner | status update every 30 min |
| SEV-2 | a game mode broken, crash rate spike, leaderboard abuse | disable the game/content via admin flag, roll back app/backend | hourly |
| SEV-3 | isolated visual defect | ticket, fix in planned patch | none |

Post-incident: blameless review within 5 working days, with action items tracked.

## Daily challenge checks

The API pre-generates 7 days ahead. Alarm `*-daily-challenge-missing` fires if today's
set cannot be served.

```bash
# Verify today and tomorrow are published
curl -s https://api.<domain>/api/v1/daily-challenge | jq '.date, (.puzzles|length)'
curl -s "https://api.<domain>/api/v1/daily-challenge?date=$(date -u -v+1d +%F)" | jq '.puzzles|length'

# Emergency: replace a broken puzzle (audited; requires ROLE_ADMIN token)
curl -X POST -H "Authorization: Bearer $ADMIN" https://api.<domain>/api/v1/admin/puzzles/<id>/disable
curl -X POST -H "Authorization: Bearer $ADMIN" https://api.<domain>/api/v1/admin/daily/<date>/regenerate
```

Never edit a live puzzle in place: replacement creates a new version and the old
attempts stay attributable to the version they were played on.

## Backups & restore drill

* RDS automated backups with point-in-time recovery: 14 days (prod), 3 days (staging).
* Targets: **RPO ≤ 5 minutes, RTO ≤ 1 hour.**
* Backups are not trusted until restored. Drill before launch, then quarterly:
  1. `aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier puzzlehub-prod-db --target-db-instance-identifier puzzlehub-restore-drill --use-latest-restorable-time --db-subnet-group-name puzzlehub-prod-db`
  2. Connect from a bastion/ECS exec task; check row counts for `users`, `attempts`,
     `daily_challenges`, `purchases` against prod and that the latest Flyway version matches.
  3. Record elapsed time (RTO actual) in the drill log; delete the drill instance.

## Scaling & capacity

* Fargate autoscaling: CPU 60% target and ALB requests/target. Raise `max_tasks` in
  `envs/prod/terraform.tfvars` if pinned at max.
* Hikari `maximumPoolSize` × `max_tasks` < RDS `max_connections` − 20 (admin headroom).
* If p95 on leaderboard reads stays > 300 ms: add the read replica / Redis per the
  scaling path in [ARCHITECTURE.md](ARCHITECTURE.md).

## Routine cadence

| When | What |
|---|---|
| Daily (launch week) | crash-free sessions, API errors, puzzle completion rates, support inbox, content reports |
| Weekly | retention by game mode, difficulty abandonment, top bugs, next content drop, ad/IAP KPIs |
| Monthly | dependency & image patching, cost review vs budget, data-retention review |
| Quarterly | restore drill, access review (IAM, Play Console, Firebase), secret rotation |
| Each release | regression suite, staged rollout, release notes, monitoring window, rollback owner named |

## Secret rotation

* JWT key: add the new key as secondary in the app config, deploy, wait > access-token TTL
  (60 min) + refresh, then promote and remove the old key.
* DB master password: rotated by RDS (`manage_master_user_password`); tasks pick it up on
  the next deployment — trigger `aws ecs update-service --force-new-deployment`.
* Play service account: create a new key in Google Cloud, `put-secret-value`, redeploy,
  then delete the old key.
