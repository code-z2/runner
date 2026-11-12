# Real-device end-to-end: scope of work

Goal: prove the v1 testnet stack on a physical iPhone — install, launch,
register with real App Attest, run, claim, escrow — against the live worker
(`https://runner-api.anyaogupeter601.workers.dev`).

## Starting state (verified 2026-11-11)

- Chain: DAO `ije-v1.sputnik-v2.testnet` governed (proposal 1 enacted);
  claims `ije-v1-claims.testnet` (0.1 N bond); escrow `ije-v1-escrow.testnet`
  (DAO owner, $5 min lock); seeder/relayer funded; token registration done.
- Worker live with v1 config, secrets, `APP_ID = QHUBYNZ482.io.wades.ije`.
- App builds clean via MCP `BuildProject` (0 warnings). Bundle `io.wades.ije`.
- Blockers carried: proposal 0 expires ~Nov 17 (finalize → 1 N back);
  proposal 2... (check status — was awaiting Joel's second vote).

## Constraints learned the hard way

- MCP tools die on long calls and do NOT respawn mid-session. Open every
  session with quick calls (`XcodeListWorkspaces`, `GetBuildLog`) before
  anything long. If the channel dies ("connection is closed"), restart the
  session — do not flail at the transport.
- `xcodebuild` CLI cannot build the app (JSON project, no pbxproj). Use MCP
  `BuildProject` instead. Never `xcrun mcpbridge` by hand.
- Physical devices do NOT support touch automation (simulators only). The app
  renders `EmptyView` on every route — there is nothing to tap. All device
  proof goes through code + console output, not screenshots.
- `RUNNER_ENV=staging` must reach the app (scheme env var or build setting);
  Debug defaults to localhost:8787, which proves nothing against the worker.

## Work items

### 1. DEBUG run-driver (no product UI)

`#if DEBUG` screen (precedent: `ProofHarness`), never ships, with buttons
wired to the real stack in `AppModel`:

- Register: `gateway.challenge()` → App Attest `registerDevice` → attest.
  (Proves real-device App Attest against staging — Joel's open proof.)
- Start / Pause / Finish: drive the real Location → Session pipeline.
- Claim: `claimPass` → build NEP-366 delegate (device key) → `relay()`.
- Seed check: fresh implicit account → `seed()` → `seeded: true` once.
- Escrow: `ft_transfer_call` lock → `unlock` with the run proof.

Test-compile via MCP `BuildProject`; fix warnings to zero via `GetBuildLog`.

### 2. Install + launch on the real iPhone

- Destination: Peso's iPhone (active). `RunProject` with generous waits;
  a timeout is NOT failure — verify via `GetConsoleOutput` / `GetBuildLog`.
  Confirm: install succeeds (provisioning + entitlements incl. new app
  group), launch shows no crash, composition root builds.

### 3. Registration proof

- Tap Register on-device. Verify server-side: device registered, real
  attestation verified (not the fake-data path). Record the device ID.

### 4. Run + claim proof

- Option A (attestation-focused): tethered Xcode location simulation with a
  GPX route ≥2.5 km. Honest caveat: proves App Attest + full money path,
  not a real run.
- Option B (full proof): outdoor run carrying the phone.
- Verify on-chain: seeded account, claim `succeeded`, runner auto-joined to
  `community`, escrow lock/unlock settled.

### 5. Cleanup items (independent)

- Proposal 0: finalize to Expired after ~Nov 17, confirm 1 N returns.
- `get_attestor` view returns `{}` (key confirmed via `get_config`) —
  inspect before mainnet.

## Definition of done

Device registered with real attestation; one 2.5 km+ run claimed on-chain
through the relay; escrow lock/unlock round-trip on test USDC; zero build
warnings; this doc updated with tx hashes and device ID.

## Proof log (2026-11-11)

- Install + launch on Peso's iPhone (iOS 27.2.1): `RunProject` ok, no crash,
  composition root builds (one QoS priority-inversion warning only).
- Register with real App Attest against the live worker: `attestSupported=true`,
  `POST /v1/challenge` -> `POST /v1/devices` 201, `REGISTER COMPLETE` twice
  (device keys `l8oYgXL+…`, `b29boGGH…`). Server accepted Apple's chain —
  not the fake-data path. Debug config temporarily `RUNNER_ENV = staging`
  so a development-attest build talks to the live worker.
- `POST /v1/seed` from the same device key returns 500 (`internal`). The
  driver payload matches `apps/api/test/seed.test.ts` field-for-field and all
  73 API tests pass locally, so the fault is server-side: live D1 likely
  missing `0002_relay_log` / `0003_seed_log` (DEPLOY has no `migrate:remote`
  step) or the seeder secret/config. Relay would hit the same gap.
- Needed before the run/claim/escrow leg: run `bun run migrate:remote` in
  `apps/api` (Cloudflare login), confirm seeder/relayer secrets and
  `get_seeder` on-chain, then relaunch the DEBUG driver — it already chains
  seed -> 3 km claim pass automatically. Still open: approved merchant + test
  USDC for the on-chain claim and escrow lock.
- Re-run 2026-11-11 11:29 UTC: third registration ok (`lDDeoqmftmYGmqKM…`),
  `POST /v1/seed` again 500 with body `{"error":"internal"}` — a non-HttpError
  throw inside the worker, consistent with missing `seed_log` table or a
  seeder-path exception. Driver now logs the response body on failure.
- Post-migration re-test 11:35 UTC: `seed` still 500 `{"error":"internal"}`.
  Assertion path proven separately: relaunch reused `k0PB6Zip0spaElfn…` with
  no new `generateKey`/`attestKey` (`reusing keyId=… assertion path`), and the
  server answered 500 rather than 401 — so `checkDevice` verified the App
  Attest assertion and the throw is downstream (`seed_log` write or the
  seeder transfer). One attestation per install; everything after is
  assertions, which respects Apple's production rate limit.
- Breakthrough 11:38 UTC: after the migration, both `POST /v1/seed` and
  `POST /v1/attestations` return 500 `{"error":"relayer_key_invalid"}` from
  the same device key via assertions only. That code comes from
  `parseRelayerKey` in `apps/api/src/nearTx.ts`, shared by the seed transfer
  and the claim path's `ensureSeeded` — so the live `SEEDER_SECRET_KEY` is
  malformed (expected `ed25519:<base58 64 bytes secret+pubkey>`) and
  `RELAYER_SECRET_KEY` likely needs the same check before relay/escrow.
  Fix: regenerate and `wrangler secret put` both keys, then relaunch.
- SEED+CLAIM PROVEN 11:46 UTC (device key `k0PB6Zip0spaElfn…`, assertions
  only, no new attestation): `POST /v1/seed` 200
  `{"seeded":true,"tx":"EKU9Uk7P5dSyH2KGpuQbLq4FNZCukgAASpnQ8rxi1Hr5"}` —
  verified FINAL on-chain, receiver
  `c9d8db220580384b5e7196ec4c557c99ec795dd90b535df6c985d56dacadce17`
  (0.005 N from `ije-v1-seeder.testnet`). `POST /v1/attestations` 201 for a
  3 km / 18 min / 180 spm run: `max_amount_cents` 150,
  `activity_hash` `e7f3fbab…`, pass `expires_at` 1794401168 (~2 h).
  Remaining: relay the treasury `claim` on-chain (needs an `is_merchant`
  account — probed `ije-dev`, `ije-dev2`, `mamaput.near`, DAO, seeder,
  relayer: all false) and escrow lock/unlock (needs test USDC for the fresh
  runner account). Claim pass expires ~2 h after issue — relay before then
  or re-run the driver for a fresh pass.
- Full driver 11:54 UTC: seed 200 (`0c138585…`, tx `CPRixzAg…`), claim 409
  `too_soon` on the reused key (4 h gap enforced), automatic one fresh
  attestation (`pgvNEC2v…`, registered 201), claim 201 max 150. Relay and
  escrow stages execute with clean skips (no merchant configured; USDC 0).
  Zero build warnings. The relay (`claim` via `POST /v1/relay`) and escrow
  (`ft_transfer_call` lock → `unlock` with run proof) code paths are staged
  in `Runner/App/StagingDriver.swift` — one relaunch after merchant + USDC
  land completes the proof.
- Stable runner 11:58 UTC: the driver now persists one NEAR keypair and the
  claim pass across launches. Account
  `19d36e6a7d05a79cae659d9a1a89284e070104eba32151752ac9f71a43c541a3`
  seeded (`DyDSL96s…`), claim 201 max 150 (via one fresh attestation after
  the expected 409 on the cooling-down key). Fund THIS account with ≥$5 test
  USDC and register a merchant; the next relaunch runs relay + escrow with no
  new attestation while the stored pass is fresh.
- ESCROW LOCK PROVEN 12:52 UTC: `ft_transfer_call` $5 lock via `POST /v1/relay`
  (assertion only, reused device key, no new attestation), relay status
  `succeeded`, tx `FbPXJ1BEvkczuAahgJ974CYGHqfUJeXTwUTZAFVRpN8C` verified FINAL
  on-chain. `get_locks` shows lock 0 for the runner, goal 3000 m. Claim cools
  until 15:01:57 UTC (4 h gap) — the driver recorded the lock and will
  automatically run claim (fitted post-lock run) → relay claim to
  `mamaput.testnet` → unlock on the next relaunch after that time.
- Two driver bugs fixed along the way: `get_locks` items key the id as
  `id` (not `lock_id`), and a shared snake-case decoder mangles explicit
  snake keys — locks now decode with a plain `JSONDecoder`. Lock 0 is
  discovered on-device; claim cools until 15:01:57 UTC (4 h rule, no
  attestation burned on attempts — a 409 only recalibrates the clock).
- FULL PROOF COMPLETE: relayed treasury `claim` to `mamaput.testnet`
  succeeded on-chain (150 cents paid, DAO debited $20→$18.50 — auto-approved,
  no council vote needed when funded). Escrow `unlock` succeeded on-chain
  after fixing the real root cause: the driver sent `"lock_id":0` (a JSON
  number) but near-sdk `U64` deserializes ONLY JSON strings, so the call
  trapped before any check ran. Fix: quote the id
  (`StagingDriverView.lock/unlockArgs`). Lesson: the escrow release profile
  sets `panic = "abort"`, so on-chain failures surface with NO message;
  consider removing it so future failures are diagnosable, and always send
  `U64`/`U128` as strings.
- ESCROW ROUND TRIP COMPLETE: unlock tx `8bWcYtwRu36sTkdh89wEev...` FINAL,
  lock 0 gone, $5 credited back, then withdrawn to the external testnet
  funder (`ije-dev.testnet`) via relayed `withdraw` (tx `7xedCw7...` FINAL).
  Escrow holds 0 for the runner; keychain account holds no funds.
- Housekeeping 2026-11-11: `Config/Debug.xcconfig` reverted to `dev`;
  `StagingDriver.swift` stays as the DEBUG-only testnet proof harness
  (never ships to TestFlight; production needs the intents-based flow so
  the keychain never custodies funds).
