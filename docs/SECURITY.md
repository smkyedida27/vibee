# Security

## Reporting a vulnerability

Email **security@[domain]** with steps to reproduce. Please don't open public issues for
security problems. We acknowledge within 2 business days and aim to fix high-severity
issues within 14 days. Good-faith research that avoids privacy violations and service
disruption will not be pursued legally.

## Baseline controls

**Transport & edge**
* HTTPS only (ALB TLS 1.3 policy, HTTP→HTTPS redirect, HSTS from the app).
* `/actuator/*` is blocked at the ALB; metrics are scraped internally only.
* ALB drops invalid headers; request body size limits enforced by the API.

**Identity & authorization**
* No API keys or service credentials in the app binary.
* Short-lived access JWTs (60 min) + rotating refresh tokens (hashed at rest, reuse
  detection revokes the family).
* Firebase ID tokens verified server-side against Google's JWKS (issuer, audience, expiry).
* Every user-scoped query filters by the authenticated `sub` — no user ids accepted from
  the client for `/me/**` resources (prevents IDOR). Admin endpoints require `ROLE_ADMIN`
  and write to `audit_log`.

**Game integrity**
* The client is untrusted: submissions are replayed and validated server-side; durations
  are server-measured; only the first attempt per puzzle counts for leaderboards.
* Idempotency keys + unique constraints on attempts, purchases and reward claims.
* Rate limits (per user and per IP) on auth, attempt submission, and purchase
  verification; anomalous scores (faster than physically possible) are flagged.
* Purchases are granted only after Google Play Developer API verification.

**Data**
* RDS in private subnets, encrypted at rest, `rds.force_ssl=1`, security group only
  allows the API tasks.
* Secrets in AWS Secrets Manager, injected at task start; least-privilege IAM per role.
* Minimal personal data; account deletion endpoint (`DELETE /api/v1/me`).
* Logs never contain tokens, purchase tokens, or emails (structured logging with redaction).

**Supply chain & CI**
* GitHub OIDC → short-lived AWS roles; no static cloud keys.
* gitleaks secret scanning, Trivy dependency and image scanning on every PR.
* Immutable ECR tags, scan-on-push; the same image digest is promoted staging → prod.
* Android signing keys only in the protected `play-release` environment; Play App Signing.
* Dependabot/Renovate for dependency updates; monthly patch window.

## Threat checklist per release

- [ ] New endpoints have authz tests (other user's resource → 404/403)
- [ ] Payload validation (size, type, enum, move counts) covered by tests
- [ ] No new secrets in code or logs (gitleaks clean)
- [ ] Third-party SDK changes reflected in Data safety + privacy policy
