<div align="center">

# 🧩 Puzzle Hub

**Five original brain games. One daily challenge. Fair to play.**

A daily puzzle hub for Android with a saga-style level map, streaks, leaderboards and a fair
free-to-play economy. Built to be polished on day one and to scale without a rewrite.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Java 21](https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white)
![Spring Boot 3](https://img.shields.io/badge/Spring%20Boot-3-6DB33F?logo=springboot&logoColor=white)
![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-ECS%20Fargate-FF9900?logo=amazonwebservices&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white)

</div>

## 🎮 The games

| | Game | Core loop |
|---|---|---|
| 🟪 | **Word Connect** | Group 16 words into 4 hidden categories |
| 👑 | **Crowns** | One crown per row, column and colour region, and crowns never touch |
| 🔢 | **Sudoku** | Classic 9×9, every board uniquely solvable |
| 🪜 | **Word Ladder** | Change one letter at a time to reach the target word |
| ➕ | **Number Merge** | Slide and merge tiles to reach the target number |

## ✨ Highlights

- **Same puzzle for everyone, every day.** A deterministic RNG and scoring rules run identically on the app and server ([contract](docs/CONTRACT.md)), so daily leaderboards are fair and cheat-resistant.
- **Plays fully offline.** Level play needs no network; daily challenges, leaderboards and sync light up when online.
- **Built to spread.** Spoiler-free, Wordle-style result sharing; invite codes that give both players 20 gems and make them friends; a friends leaderboard; on-device daily reminders that protect your streak; and a well-timed review prompt.
- **Fair economy.** Coins, lives and boosters you can earn by playing; purchases and ads are optional ([design](docs/MONETIZATION.md)).
- **Production-grade from the start.** Modular monolith, Flyway migrations, rate limiting, Testcontainers tests, Prometheus + Grafana, Terraform for AWS, and CI/CD with staged promotion to prod.

## 🏗️ Stack

**App:** Flutter · Play Billing · AdMob  
**API:** Spring Boot 3 / Java 21 modular monolith · PostgreSQL 16  
**Cloud:** AWS ECS Fargate · RDS · CloudFront · Terraform  
**Delivery:** GitHub Actions (CI, staging → prod deploy, signed Play releases)

## Repository layout

```
app/        Flutter app (package `puzzle_hub`)
backend/    Spring Boot API (Maven, ./mvnw), Flyway migrations
content/    Shared puzzle content (word list, curated Word Connect puzzles)
docs/       Contract, architecture, runbook, monetization, release & security docs
infra/      docker-compose for local dev, observability, Terraform for AWS
scripts/    content sync/check, post-deploy smoke test
.github/    CI/CD workflows
```

## Quickstart

Prerequisites: Docker, Java 21+, Flutter (stable), Make. Terraform only for infra work.

```bash
make up            # Postgres + API on http://localhost:8080 (Swagger UI at /swagger-ui.html)
make smoke         # hit the local API end to end
make app-run       # run the app; Android emulator reaches the host API at 10.0.2.2:8080
make up-obs        # + Prometheus :9090 and Grafana :3000 (dashboard "Puzzle Hub — API")
make down
```

Tests and checks:

```bash
make backend-test  # unit + Testcontainers integration tests
make app-test      # flutter analyze + flutter test
make content-check # app/backend copies of content/ must match
make lint          # everything static, incl. terraform validate + actionlint
```

The app works fully offline for level play; point it at an API with
`--dart-define=API_BASE_URL=https://api.example.com` to enable daily challenges,
leaderboards, sync and purchases.

## Shared content

Edit puzzle content only in `content/`, then `make content-sync`. CI fails if the app or
backend copies drift. Game rules, the deterministic RNG and scoring are defined in
[docs/CONTRACT.md](docs/CONTRACT.md) and implemented identically on both sides.

## Deploying

1. One-time per AWS account: `infra/terraform/bootstrap` (state bucket, lock table,
   GitHub OIDC roles).
2. Per environment: `infra/terraform/envs/{staging,prod}` — copy `backend.hcl.example`
   and `terraform.tfvars.example`, then `terraform init -backend-config=backend.hcl && terraform apply`.
3. Merge to `main` → `deploy-backend` ships to staging, smoke-tests, then waits for
   approval to promote the same image to production.
4. Tag `vX.Y.Z` → `release-android` builds a signed AAB and uploads it to the Play
   internal track.

Repository secrets/variables used by workflows: `AWS_DEPLOY_ROLE_ARN`,
`AWS_PLAN_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, `TFVARS_STAGING`, `TFVARS_PROD`,
`STAGING_API_URL`, `PROD_API_URL`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_SERVICES_JSON`,
`PLAY_SERVICE_ACCOUNT_JSON`, and the AdMob variables `ADMOB_APP_ID_ANDROID`,
`ADMOB_REWARDED_ANDROID`, `ADMOB_INTERSTITIAL_ANDROID` (the release build fails without them
rather than shipping Google's test ads).

## Documentation

* [Client/server contract](docs/CONTRACT.md)
* [Architecture & scaling path](docs/ARCHITECTURE.md)
* [Operations runbook](docs/RUNBOOK.md)
* [Monetization & economy](docs/MONETIZATION.md)
* [Release checklist (Play Console)](docs/RELEASE_CHECKLIST.md)
* [Security](docs/SECURITY.md) · [Privacy policy template](docs/PRIVACY_POLICY.md)
