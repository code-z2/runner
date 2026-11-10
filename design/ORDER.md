# Order of Operations — Agreed Build Sequence

Living spec. One item at a time. Discuss first, append only as agreed. No UI.
Source concept: `design/product.md`.

## Agreed order (P0 first)

1. F01 — start, pause, resume, finish
2. F02 — live metrics (distance, time, pace)
3. F03 — cadence tracking
4. F11 — works without payments
5. S01/S02/S03/S05/S06/S07 — passive discovery, vibration, pass-by count, anon IDs, dedup
6. A01/A03/A04/A05/A06 — PacePilot state engine, encouragement, cadence target, 1-2 audio, hold-it feedback
7. M01/M03/M05/M07 — merchant discovery, merchant-defined offers, QR claim
8. C05/T01–T10 — community treasury on Sputnik/Trezu, attested claims, admin + pause/recovery
9. Wallet stack — Apple OAuth, NEAR intent wallet SDK, NEAR escrow
10. Goals + goal-lock escrow (G01–G06) + full audio engine + run reports
11. Platform defaults — device history/bests, HealthKit, ActivityKit, retention, Apple Intelligence

---

## 1. F01 — Start, pause, resume, finish (AGREED)

Assumption: numbers-only session. No route map in F01.

- Start: explicitly user-initiated. Includes 3-2-1 countdown (audio hook, implemented at AI point).
- Pause/resume: explicitly manual only. App never auto-pauses.
- On-detect pause: app detects likely stopped (stillness via location/motion) and nudges user to pause via audio/haptic/Live Activity. Prompt only, no state change.
- Resume: explicitly manual only.
- Finish: explicitly user-initiated only.
- Crash/kill recovery: last persisted state is cut as a completed run. Example: 5K goal, dies at 3.5K → next open shows 3.5K logged as if manually ended.
- Background/locked: recording continues. Live Activity + Dynamic Island for state/controls.
- Battery context: surface battery level context to user (exact thresholds TBD, audio hook for low battery).
- Audio hooks noted, deferred to AI spec: start countdown, +1K announcements, endgame 400-300-200-100-50-complete when a K goal is set, stopped-detected prompt.
- Deferred, not discarded: goals logic → item 10, full audio engine → item 10. Out of scope: route map.

Open for later: stop-detection thresholds, persist cadence, crash-run flagged interrupted vs plain complete, battery thresholds.

---

## 2. F02 — Live workout metrics (AGREED)

Assumption: live = what the system measures. No synthetic filling.

- Live fields: distance, elapsed time, pace (current/average), cadence, heart rate (when available), progress toward goal.
- Heart rate: phone has no HR sensor. Show only what the system delivers (Watch/BLE HR via HealthKit). Never estimate.
- Elapsed time: wall time from Start. Pause freezes everything. Resume continues same session. No background accumulation while paused.
- Distance: Core Location deltas as delivered by iOS. No custom hardware-level filtering.
- Current pace: checked — iOS has no direct pace API. Derived from `CLLocation.speed` / distance-over-time when valid; invalid speed (negative) treated as unknown. Average pace = distance / active elapsed. No invented smoothing beyond iOS `horizontalAccuracy`/timestamps.
- Weak GPS: leverage iOS defaults (`desiredAccuracy`, `activityType=.fitness`, `pausesLocationUpdatesAutomatically=false`). Show unknown rather than guess. Exact accuracy gating TBD at build.
- Out of scope: route map, custom Kalman/smoothing, HR estimation.

---

## 3. F03 — Cadence tracking (AGREED)

Assumption: keep it simple, use what iOS gives. No custom step detection.

- Source: `CMPedometer` cadence when available. Watch sensors optional later. No fallback estimation.
- Unavailable placement/device: show unknown. Never synthesize.
- Retention: keep best-resolution samples for AI work. 1-hour rolling window of high-rate samples to bound space; size expected small so prefer keeping full session if cheap. Exact sample rate TBD at build.
- Out of scope: fixed 180 spm target. Form inference deferred entirely beyond items 9–10.

---

## 4. F11 — Works without payments (AGREED)

Assumption: fitness core has zero dependency on money. Money paths are passive readers.

- Default: tracking, history, encounters, events all work with no wallet, no deposit, no token.
- Money modules never require sync/push from the running app. The running app does not notify or sync with money contracts; they read activity on demand.
- Goal-lock example: user locks $10 on a 10K goal. Funds do not sit in escrow forever. If a later valid activity surpasses the goal, escrow unlocks. If the user cannot make it, they may explicitly forfeit: 50% back to user, 50% to community pool.
- Wallet surfaces (e.g. cards section) stay visible/seeable but inert for no-wallet users. No prices/balances forced into the core workout experience.
- Social auth required only at wallet entry, never for running. Wallet entry uses NEAR social login: OAuth identity maps to the runner's NEAR account, no seed phrase managed by the runner. Same address across sessions; sessions are ephemeral and re-authenticated.
- Deferred, not discarded: specific OAuth provider choice, wallet SDK, lock contract shape → item 9.

---

## 5. S01/S02/S03/S05/S06/S07 — Passive encounters (AGREED)

Assumption: counts are display-only numbers. Main interaction is IRL between runners.

- Proximity: tuned to roughly the width of a standard track field. Opposite-direction approach-and-pass is the reference case.
- One pass = one count. Track three display-only counters: (a) first-time passes, (b) repeat passes, (c) close-proximity dwell over ~1 minute.
- Rotating anonymous IDs on BLE. Rotation must not inflate counts: same app instance in one encounter window resolves to one encounter despite ID rotation.
- Raw encounter events stay on device. Counts carry no in-app powers or rewards.
- Haptics: graded pulse intensity — lighter at distance, heavier at proximity. Cooldown to avoid repeat buzzing.
- Out of scope: map of strangers, identity exchange, cross-device correlation beyond one encounter window.

---

## 6. A01/A03/A04/A05/A06 — PacePilot live coach (AGREED)

Assumption: this is where most AI + audio lives. Quiet by default, never enforcing.

- States: warm-up, steady, accelerating, interval, recovery, cooldown. Set as specified.
- Interruption policy: stays quiet most of the time. Speaks only when useful. Balanced levels, no chatter.
- Faster encouragement: only on computed evidence the body can push a little. Suggestive tone only, e.g. "based on your activity, you could run a little faster." If runner complies: brief praise ("great, hold it — don't push too hard"). If struggling: back off, never pressure.
- Cadence target: personal baseline-based, never fixed 180.
- Rhythmic guidance: tick-tock / "1,2,1,2… keep it up" beats at target step interval to build rhythm. Fade beats once stable; re-enter only if drifting off target.
- Includes earlier F01 audio hooks: 3-2-1 countdown, +1K calls, endgame 400-300-200-100-50-complete on K goal, stopped-detected nudge, battery nudge.
- Out of scope: medical diagnosis, breathing restriction, head/posture verification. Deferred: long-term plan + full audio engine → item 10. Form inference deferred entirely.

---

## 7. M01/M03/M05/M07 — Merchants + redemption (AGREED)

Assumption: redemption = spending from the community 2-of-N multisig (runner + attestor). No separate voucher step.

- Registration: merchants enroll via dedicated web platform. Structured product categories. Water is mandatory, other categories allowed.
- Discovery: app shows participating locations only. It does not show live inventory/offers. Runner goes on-site and merchant states what is redeemable.
- Redemption: QR only. No NFC/tap path.
- Claim location: on-ground only, at the merchant. No pre-claim or reservation.
- Eligibility: only with a completed activity of 2.5K+ attested by the server (reasonable distance over a continuous duration). Attestation is checked onchain at claim time.
- Double-spend: prevented by onchain multisig controls (single-use claim, treasury balance check), not by app UI.
- Out of scope: NFC, inventory sync, pre-ordering.

---

## 8. C05/T01–T10 — Treasury on Sputnik/Trezu + claim policy (AGREED)

Assumption: simple single-spend allowance per activity. No daily budgets.

- No global daily cap. No per-runner daily cap.
- One server attestation = one redemption. Each completed activity grants at most one claim attestation.
- Claim window: 2 hours from attestation. Expired claims are unusable and hidden — app only surfaces live claimable allowances, never expired ones for retry.
- Failed/unused claims: retryable until used or expired. No reservation step; single atomic spend.
- Spend limit per claim: $5 max, and $0.50 per km completed. Example: $2.50 allowance spent as $1 still consumes the full activity allowance — one claim only, no remainder.
- Merchant registry: merchant addresses committed onchain. QR payment only routable to a registered merchant address. Approval, location, and metadata stay on the server.
- Multisig shape: 2-of-N (runner + attestor). Attestation verification is a co-sign, not a simpler verifier pattern.
- Admin: built on Sputnik/Trezu, including admin roles, pause/recovery, parameter changes. Admin never bypasses verified-merchant + attestation + single-use checks.
- Deferred, not discarded: personal goal-lock escrow (G01–G06) → item 10.

---

## 9. Wallet stack (AGREED)

- OAuth: Apple only for now. NEAR social login; builds on item 4.
- Wallet SDK: NEAR cross-chain intent wallet via NEAR SDK integration.
- Lock contract: escrow on NEAR. Holds personal goal-lock funds only. Never mingled with community treasury.

### 9a. RunnerAuth (AGREED)

- Two identities, one box: Apple identity (Sign in with Apple → server-verified) for API auth; NEAR passkey session (item RunnerNear) for chain ops. Works without payments: NEAR session optional, Apple required.
- Scopes: request fullName + email; both first-presentation-only, downstream treats them as optional. Never asks twice, never gates on them.
- Nonce: 32 random bytes; SHA-256 hex goes in the request, server verifies the same hash in the token.
- Keychain: `whenUnlockedThisDeviceOnly`, no iCloud sync, access-group constant reserved for the Watch app, silent (no biometry) for session tokens. Single `runner.account.v1` blob, atomic.
- Presentation stays app-layer (anchor + modern `init(url:callback:)` with `.https`): the package exposes request values, token parsing/validation, session store, coordinator. No UIKit, no Auth0.swift dependency.
- Chain signing programs against RunnerNear's `NearSigner`; day-3 local-key fallback lands as a `LocalKeySigner` on the same protocol with no app-layer changes.

## 10. Goals + goal-lock escrow + full audio + run reports (AGREED)

- Goals logic: user specifies amount to lock and agrees. Funds move from personal wallet to escrow on agreement.
- Unlock: a later valid activity that surpasses the goal unlocks the escrow.
- Forfeiture: user-explicit only when the goal cannot be met (funds must not sit forever). On forfeit, 50% back to user, 50% to community pool. No auto-failure, no timeout, no retry window.
- Full audio engine beyond item 6 hooks (item 6 owns live-coach behavior; this owns engine depth).
- Run analysis: data-driven algorithm over run history producing reports. Not clinical. Form inference deferred entirely, no video analysis.

## 10a. Escrow package (AGREED 2026-11-09)

- Token: USDC only. Amounts are base-unit strings end to end; no floats cross the seam.
- Attestor: the same backend key that signs treasury claim passes. The run proof arrives in the same server response (`run_proof` + `run_proof_signature`); the app forwards both into `unlock` and never verifies locally — the contract is the source of truth.
- Submission: the relayer submits every state-changing call (`ft_transfer_call` lock, `unlock`, `give_up`, `withdraw`, `lock_from_balance`) because only a full-access key can attach the 1-yocto deposit. The relayer endpoint shape is Joel's; the package carries the submitter as a seam with a mock, no invented HTTP.
- Slice: package only — typed models, `EscrowFunctions` seam, live RPC views, relayer submitter seam, mocks, Swift mirrors of the contract tests. Goals UI, audio engine, run reports stay later.
- Deploy values (escrow/treasury/token accounts, `min_lock`) land from Joel's deployment; until then the package's placeholders are syntactically valid but nonexistent accounts, so every call fails closed at RPC.

## 11. Platform defaults (AGREED)

- History: device only. Bests: device only.
- HealthKit: native iOS integration (save workouts, read only authorized data).
- Lock screen: ActivityKit during an actual activity only.
- Retention: most data on device + Keychain. Apple Intelligence by default for AI; mostly on-device execution.
- Merchant settlement dashboard: nil, not needed. Receipts: nil, onchain transactions are enough.

## 12. Backend API (AGREED)

Assumption: Peter handed the lead and all open decisions to Joel on 2026-11-08. Full contract in `design/API.md`.

- Server jobs: sign claim passes for finished runs, keep the merchant list, merchant sign-up and admin approval. Nothing else.
- Claim pass: the attestor's signature is the second signature of the 2-of-N. No server call at the merchant.
- Faked-run guard: no overlap with, and at least 4 hours after, the last attested run, per NEAR account and per device.
- Oldest run that can be attested: 6 hours after it ended.
- Steps required for a claim pass.
- Amount: runner types it after scanning the merchant's fixed QR.
- Merchant sign-in: email link via Resend.
- Admin approval holds no DAO key: the DAO proposal passes first, the server checks the contract, then shows the merchant.
- Stack: Cloudflare Workers + D1, TypeScript, bun.

## 13. Money model and coach opt-in (AGREED)

Assumption: Peter's call on 2026-11-09, Joel leads.

- No private balance in the app. Money lives in two places only: the DAO community treasury (2-of-N claims, item 8) and each runner's personal goal escrow.
- Anyone can fund the treasury from any chain through NEAR Intents. The swap delivers the treasury token to the treasury contract; no app balance in between.
- Goal escrow: the runner locks their own money on a goal. A later run that beats it unlocks the money, which stays in the same escrow contract until the runner moves it out. Give up any time: half back, half to the pool (item 10).
- PacePilot is opt-in only. Off by default; the live coach card shows only when it is on.

## 14. Treasury on Sputnik DAO (AGREED)

Assumption: Joel, 2026-11-10, reading item 8 "Treasury on Sputnik/Trezu" as the pool's funds living in a Sputnik DAO.

- The pool's money lives in a Sputnik DAO v2 managed through Trezu. Council: Joel and Peter, both must approve.
- contracts/treasury becomes the claims module: no funds, the single member of a "claims" role that may only add and approve Transfer proposals, 1-of-1.
- A claim checks the attestation, single use, registered merchant and cap, then adds and approves a DAO Transfer to the merchant in the same transaction. No votes per claim.
- The module holds the only attestor key; the goal escrow reads it from there. Council changes it through a FunctionCall proposal.
- Goal escrow funds stay in the escrow contract; the pool's half on give up goes to the DAO.
- Donations go straight to the DAO as a plain token transfer.
