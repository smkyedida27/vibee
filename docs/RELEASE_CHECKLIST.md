# Release Checklist

Copy into the release issue for every Android release. Verify all Play items against
current Google guidance at submission time — policies change.

## Build & versioning
- [ ] Version `X.Y.Z` tag created from `main`; `versionCode` (CI run number) higher than the live release
- [ ] Package id `com.puzzlehub.app` unchanged; release signed via `release-android` workflow (Play App Signing enabled)
- [ ] Target SDK meets the current Play requirement (https://developer.android.com/google/play/requirements/target-sdk)
- [ ] R8/obfuscation mapping and native debug symbols uploaded (workflow does this)
- [ ] `API_BASE_URL` points to production; no debug flags, test ad unit ids replaced by production ids via config

## Quality
- [ ] CI green: analyze, tests, backend verify, content check
- [ ] Installed from the internal track on ≥ 3 real devices (low-end 3 GB RAM, mid, tablet)
- [ ] **Upgrade path**: install previous production build, play, then upgrade → progress, coins, streak intact
- [ ] Fresh install → first win in < 60 s without sign-up
- [ ] Today's and tomorrow's daily challenges validated on production API
- [ ] Offline: airplane mode → levels playable, daily shows cached/offline state; reconnect syncs
- [ ] Font scaling 200%, TalkBack on main flows, reduced-motion setting honoured
- [ ] Purchases tested with license testers: each consumable, remove_ads, VIP subscribe/cancel/restore
- [ ] Rewarded ad grants reward; interstitial never shown mid-puzzle or after a failed level
- [ ] No critical/high open defects; known limitations documented in release notes

## Play Console — App content
- [ ] **Privacy policy** URL live and accurate ([PRIVACY_POLICY.md](PRIVACY_POLICY.md))
- [ ] **Data safety** form matches reality: device/install IDs (analytics, ads), crash logs, purchase history, user IDs, optional email (account link); encryption in transit; deletion available
- [ ] **Account deletion**: in-app (Settings → Delete account) and a web URL listed in Play Console
- [ ] **Ads** declaration: "Contains ads" = yes
- [ ] **Content rating** (IARC) questionnaire: no violence, no simulated gambling; re-submit if features changed
- [ ] **Target audience**: 13+ (if under-13 ever included → Families policy, certified ad SDKs)
- [ ] **In-app products** active with correct prices/translations; subscription base plan + offer configured
- [ ] **News app / financial / health** declarations: not applicable — confirm
- [ ] Permissions: only `INTERNET`, `POST_NOTIFICATIONS` (runtime, opt-in), `com.android.vending.BILLING`, AD_ID (declared)

## Testing track requirements
- [ ] New personal developer accounts: closed test with the required number of testers for the required continuous period before production access (check current numbers in Play Console Help)
- [ ] Pre-launch report reviewed (crashes, accessibility, security warnings)

## Store listing
- [ ] App icon 512×512, feature graphic 1024×500, phone + 7"/10" tablet screenshots (original artwork only)
- [ ] Short/long description, no misleading claims or keyword stuffing; support email + website
- [ ] Release notes per language

## Backend & ops
- [ ] Backend version compatible with both the new and previous app versions
- [ ] Dashboards/alarms green; backups recent; rollback owner named in the release issue
- [ ] Budgets alert configured; on-call aware of release window

## Rollout
- [ ] Staged rollout: 5% → 20% → 50% → 100% with ≥ 24 h between steps
- [ ] Gate each step: crash-free sessions ≥ 99.5%, ANR rate below Play bad-behaviour threshold, no new 1★ cluster, API 5xx < 1%
- [ ] Halt rollout immediately on a SEV-1/2 (see [RUNBOOK.md](RUNBOOK.md))
