# Monetization & Economy Design

Goal: sustainable revenue **without** degrading the puzzle experience. The game must
remain fully enjoyable for a player who never pays and never watches an ad
(product spec guardrail). Revenue comes from convenience, cosmetics and supporting a
habit — never from blocking a puzzle mid-play or misrepresenting rewards.

## Currencies & resources

| Resource | Earned by | Spent on | Authority |
|---|---|---|---|
| **Coins** (soft) | completing levels (10–30 by stars), daily challenge (50), streak milestones, daily login, lucky spin | hints (100), undo packs, cosmetic themes | local-first, backed up in progress snapshot |
| **Gems** (hard) | IAP, 7-day login calendar day 7, rare spin slot | heart refill (30), 5-hint pack (20), 1000 coins (25) | **server** ledger (`/me/wallet`) |
| **Hearts** (lives) | regen 1 per 20 min, max 5 | 1 heart lost when a *level* run fails (Connect 4 mistakes, Sudoku 3 mistakes, Merge board locked). Daily challenges never cost hearts. | local; VIP = unlimited |

Rules:
* A puzzle that is in progress is **never** interrupted to sell anything.
* Out-of-hearts screen offers, in this order: wait timer, watch an ad for +1 heart (cap
  3/day), refill with gems. It always shows the free option first.
* Daily challenges are free forever; they are the retention core.
* Prices are shown in local currency from Play Billing; gem costs are shown before any spend.

## IAP catalog (Google Play)

| Product id | Type | Grants | Price anchor (USD) |
|---|---|---|---|
| `gems_small` | consumable | 80 gems | 0.99 |
| `gems_medium` | consumable | 500 gems (+25% "popular") | 4.99 |
| `gems_large` | consumable | 1200 gems (+50%) | 9.99 |
| `gems_mega` | consumable | 3000 gems (+87% "best value") | 19.99 |
| `remove_ads` | non-consumable | no interstitial/banner ads forever (rewarded ads remain optional) | 3.99 |
| `vip_monthly` | subscription (3-day free trial) | no ads, unlimited hearts, 2× coins, 3 free hints/day, exclusive board theme | 4.99/mo |

All grants are performed server-side after Play Developer API verification
(`POST /purchases/google/verify`), idempotent per `purchaseToken`, and the purchase is
acknowledged within 3 days (Play auto-refunds unacknowledged purchases). Subscription
state changes arrive through Real-time Developer Notifications (Pub/Sub → backend).

## Advertising (AdMob)

| Format | Placement | Caps |
|---|---|---|
| Rewarded | player-initiated only: free hint, +1 heart, double level coins, extra spin | 3 per reward type per day, 10 total/day |
| Interstitial | **only** on the results screen transition, after the player taps "Continue" | min 3 completed levels between; min 3 min apart; never in first session or first 2 days; never after a failed level; never for `remove_ads`/VIP |
| Banner | none in gameplay; optional on the level map only, below content (A/B tested) | — |

Never: ads covering controls, ads before the first win, ads mid-puzzle, fake close
buttons, rewards that aren't delivered. Use Google's UMP SDK for consent (GDPR/UK/CCPA)
before requesting ads; serve non-personalized ads when consent is not given. Families
policy: the app targets 13+; if the audience ever includes children, switch to
families-certified ad SDK settings.

## Engagement loops that support revenue (not pressure)

* **Saga level map** across all 5 games — stars gate cosmetic chests, not progress.
* **7-day login calendar** (coins → gems on day 7); missing a day restarts the calendar,
  it does not take anything away.
* **Daily lucky spin** (free once/day, +1 via rewarded ad). Odds are published in-app.
* **Streaks** for the daily challenge; one free "streak freeze" per week, more via coins.
  No paid streak repair (avoids exploiting loss aversion).

## KPIs

| KPI | Definition | Launch target (review after 30 days) |
|---|---|---|
| D1 / D7 / D30 retention | returning players | 40% / 18% / 8% |
| ARPDAU | (IAP net + ad revenue) / DAU | $0.04–0.08 |
| Payer conversion | payers / MAU | 1.5–3% |
| ARPPU | IAP net / payers | — |
| Rewarded ad opt-in | users watching ≥1 rewarded ad / DAU | 25–40% |
| Ad impressions per DAU | all formats | ≤ 4 (guardrail, not target) |
| LTV (D90) | cohort cumulative revenue per install | must exceed blended CPI before scaling UA |
| Refund rate | refunds / purchases | < 2% |

Guardrail metrics for every monetization test: D1/D7 retention, session length,
puzzle completion rate, 1★ review rate. A test that lifts ARPDAU but drops D7 by more
than 1 pp is rejected.

## A/B test plan (Firebase Remote Config + A/B Testing)

1. **Interstitial cadence:** every 3 vs 5 levels — primary ARPDAU, guardrail D7.
2. **Starter pack:** one-time 80 gems + remove-ads bundle at $1.99 shown after level 10
   vs none — primary conversion.
3. **Gem pack anchoring:** 4 packs vs 3 packs with "best value" badge — ARPPU.
4. **VIP trial length:** 3 vs 7 days — trial→paid conversion and 60-day retention.
5. **Heart regen:** 20 vs 30 minutes — retention vs gem spend.

Run one test per surface at a time, minimum 2 full weeks, pre-registered success metric,
and ship only on statistically significant wins.

## Compliance

* Play Billing for all digital goods; no external payment links.
* Disclose ads, IAP and data collection accurately in the Play listing and Data safety form.
* Loot-box style rewards (lucky spin) publish odds; no paid random rewards.
* Respect platform age-rating questionnaire answers (simulated gambling: **no**).
