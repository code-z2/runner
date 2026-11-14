# System Log — Runner

Living record of what was built. Update on every completed item.

## Entry template

- Item:
- What it is:
- How it was done:
- Why this way:
- Importance:
- Metadata: files, APIs, versions, dates

## 2026-11-05 — Order-of-operations spec (items 1–11)

- Item: design/ORDER.md agreed sequence + per-item specs
- What it is: discussion-first specs for F01/F02/F03/F11, encounters, PacePilot coach, merchants, treasury 2-of-N, wallet stack (Apple + NEAR), goal-lock escrow, platform defaults
- How it was done: one-feature-at-a-time discussion, appended only as agreed, no UI
- Why this way: AGENT.md discuss-then-build; keeps fitness core independent of money paths
- Importance: build sequence source of truth; product.md remains concept inventory
- Metadata: design/ORDER.md, design/product.md; 2026-11-05

## 2026-11-07 — Step-1 scaffold

- Item: foundations scaffold (packages, apps/ios shell, apps/api stub, hook)
- What it is: 10 flat SwiftPM packages with namespace shells, hand-written
  Runner.xcodeproj (Debug/Staging/Beta/Release), App shell, zero-dep Bun api
  stub, pre-push format:check hook
- How it was done: research-first (wades-app layout, AppEnvironment pattern),
  built step by step, audited against swift-coding-guideline, verified by build
- Why this way: auditable single-responsibility boxes, no UI, flat packages
  without swift-java plumbing
- Importance: ground all later package steps stand on
- Metadata: packages/Runner*, apps/ios, apps/api, tools/git-hooks/pre-push; 2026-11-07

## 2026-11-07 — Step-2 RunnerLocation

- Item: RunnerLocation package (ORDER §2, F02 location half)
- What it is: LocationTracker actor, LocationUpdateSource protocol with live
  (CLLocationUpdate.liveUpdates fitness + CLServiceSession whenInUse) and mock
  sources, pure event mapper, sample model with unknown-on-invalid
- How it was done: research-first (Apple docs, SDK headers, HIG), TDD with
  Swift Testing (14 tests, red then green), local skills test-driven-development
  + write-swift auditing
- Why this way: handler-based source keeps retention sound; mapper pure for
  testability; pace math stays in RunnerSession
- Importance: first audited foundation box; sets the package pattern
- Metadata: packages/RunnerLocation, iOS 26 + macOS 15 platforms; 2026-11-07
  (platform bump applied to all packages + app target; Testing/Tests targets
  land per package with its build step)

## 2026-11-07 — Step-3 RunnerCadence

- Item: RunnerCadence package (ORDER §3, F03)
- What it is: CadenceTracker actor, CadenceUpdateSource protocol with live
  CMPedometer source and mock, pure event mapper, sample model with
  nil-on-missing, pure start-policy truth table
- How it was done: research-first (Apple docs, SDK headers, running-app
  sources), TDD with Swift Testing (11 tests, red then green), local skills
  test-driven-development + write-swift auditing
- Why this way: handler shape matches the SDK; mapper and policy pure for
  testability; single shared pedometer; pause-gap backfill owned by session
- Importance: telemetry half complete; session step consumes both streams
- Metadata: packages/RunnerCadence; 2026-11-07
- Gaps: live sensor path not executable on Mac (iOS-only APIs, no hardware);
  verified by header conformance, compiles under availability gate

## 2026-11-07 — Step-4 RunnerSession

- Item: RunnerSession package (ORDER §1, F01 state machine + clock)
- What it is: WorkoutSession actor, monotonic-segment elapsed clock, atomic
  JSON snapshots on transitions plus explicit checkpoint, static crash-cut
  recovery, finish reasons, battery levels at start and end
- How it was done: research-first (Apple docs, papaSteps spec), TDD with
  Swift Testing (18 tests, red then green), local skills auditing
- Why this way: accumulated segments immune to sleep and clock shifts;
  recovery cuts at last snapshot, never estimates; idempotent finish
- Importance: the session all other boxes orbit; telemetry packages plug in next
- Metadata: packages/RunnerSession; 2026-11-07
- Open: checkpoint cadence + launch-time recovery wiring belong to app layer

## 2026-11-07 — Step-5 RunnerStore + toolchain policy

- Item: RunnerStore package (ORDER §11, device history + bests)
- What it is: RunRecord @Model with V1 schema + migration plan, RunStore
  @ModelActor with idempotent record, capped recentRuns, on-demand bests;
  snapshots cross the boundary, never models
- How it was done: research-first (Apple docs, verified persistence guides),
  design skills api-and-interface-design + planning-and-task-breakdown
  consulted (contract-first, idempotency key = run ID, additive schema),
  TDD with Swift Testing (5 tests, red then green), local skills auditing
- Why this way: actor executor is the idempotency atomicity; schema history
  never deleted; container owned by app layer
- Importance: history + bests box done; HealthKit next
- Metadata: packages/RunnerStore; 2026-11-07
- Also: Swift 6.4 policy — swift-tools 6.4 everywhere, SWIFT_VERSION stays
  6.0 (compiler maximum), iOS 26.0 minimum with latest SDK; recorded in AGENT.md

## 2026-11-07 — Step-6 RunnerHealthKit

- Item: RunnerHealthKit package (ORDER §11, HealthKit boundary)
- What it is: HealthKitGateway protocol (access, save, HR read, live stream);
  live store saves via HKWorkoutBuilder with distance sample, reads HR via
  sample query, live stream honestly unavailable until Watch step
- How it was done: research-first (Apple docs, SDK headers, running-app
  patterns), TDD with Swift Testing (5 tests, red then green), local skills
  auditing; compiler pothole fixed by pinning continuation result type
- Why this way: passive by design (builder save, no live session) keeps F11;
  minimal scopes (workout write + HR read); body metrics stay out of HealthKit
- Importance: phone enrichment done; Watch step plugs the live seam
- Metadata: packages/RunnerHealthKit; 2026-11-07
- Gaps: live path not executable on Mac; entitlements + usage strings land
  with app target

## 2026-11-07 — Step-7 RunnerEncounters

- Item: RunnerEncounters package (ORDER §5, BLE encounters)
- What it is: pure ledger (first/repeat/dwell, 30-day prune), pure RSSI
  grader with cooldown, rotating identifier, tracker actor with session pump,
  live CoreBluetooth dual-role pair with state restoration, system haptics
- How it was done: research-first (BLE vs UWB vs Wi-Fi Aware vs MPC
  full-sack review; BLE only viable transport), TDD with Swift Testing
  (16 tests, red then green), local + swift-concurrency-expert auditing
- Why this way: identity-free background packets, OS-peripheral-ID dedup,
  rotation-proof windows; pump drains before stop clears state (test-caught)
- Importance: passive social core done; hardware smoke tests queued post-packages
- Metadata: packages/RunnerEncounters; 2026-11-07
- Gaps: live BLE needs two real radios (compile-verified only); BT permission
  + background modes land with app target

## 2026-11-08 - Backend API decisions + runner-api worker

- Item: ORDER §12 backend API (attestor, merchant registry, merchant portal API)
- What it is: Cloudflare Worker + D1 in apps/api. Runner routes: challenge,
  App Attest device registration, claim pass (attestation) for a finished
  run, merchant discovery by geohash cell. Portal routes: email sign-in,
  merchant locations, admin review. Hourly cleanup job.
- How it was done: the 5 open questions in design/API.md settled (Peter handed
  the lead to Joel); pure parts split out (eligibility, geohash, NEP-413,
  claim pass signing); 42 bun tests over an in-memory SQLite stand-in for D1;
  tsc strict; wrangler dry-run bundle (~680 KiB)
- Why this way: the attestor's ed25519 signature over the exact pass bytes is
  the 2-of-N co-sign, so the server is not on the claim path; no DAO key on
  the server, admin approval only reads the contract; overlap + 4 hour gap
  per account and per device is checked and written in one statement
- Importance: unblocks item 7 (merchants) and item 8 (treasury claim) once the
  contract exists
- Metadata: apps/api, design/API.md, design/ORDER.md §12; deps @noble/curves,
  @noble/hashes, @scure/base, cbor-x, @peculiar/x509, reflect-metadata;
  2026-11-08
- Gaps: App Attest key registration is only tested against bad input; needs
  one real device run. Assertion check assumes the signature is ECDSA-SHA256
  over SHA256(authData || SHA256(payload)); confirm on device. Treasury
  contract (is_merchant, claim) not built yet. D1 database, vars and secrets
  (ATTESTOR_SECRET_KEY, RESEND_API_KEY) not created yet. Merchant portal web
  app not built yet.

## 2026-11-08 - Treasury contract

- Item: ORDER §8 treasury claim policy (C05/T01-T10)
- What it is: NEAR contract in contracts/treasury. Holds one stablecoin,
  pays registered merchants against an attestor-signed claim pass sent by the
  runner's own account (2-of-N), one use per pass, failed transfers free the
  pass. DAO owner manages merchants, attestor key, pause and recovery.
- How it was done: near-sdk 5.30.1; 18 unit tests with near-sdk unit-testing
  and ed25519-dalek signing real passes; built with cargo near in the pinned
  sourcescan/cargo-near:0.22.0-rust-1.99.1 image (digest in Cargo.toml),
  wasm 161,282 bytes, sha256 108bf492...a438f513
- Why this way: verifying the exact pass bytes the server signs keeps the
  server off the claim path; the pass is marked used before the transfer so
  two claims cannot race; recovery only to the DAO and only while paused, and
  no upgrade method, so no admin path pays an unknown account
- Importance: closes the money path for items 7 and 8 end to end, apart from
  deployment
- Metadata: contracts/treasury, design/API.md; 2026-11-08
- Gaps: not deployed; needs testnet run with a real token and Sputnik DAO
  proposal for add_merchant; no integration test against a live sandbox yet

## 2026-11-08 - runner-api deployed (test)

- Item: Cloudflare setup for runner-api
- What it is: worker live at https://runner-api.anyaogupeter601.workers.dev,
  D1 runner-api (62403d0b-151e-480d-8775-f1be4a325256, WEUR) with schema,
  hourly cleanup cron, ATTESTOR_SECRET_KEY stored as a secret. Attestor
  public key: ed25519:5nkc2NppUmiqBDaZYKjsgXigejTzmNzXeRzY336BXcUb
  (retired 2026-11-10, see "v1 accounts live" below)
- How it was done: wrangler 4.158.0 on account f1e022c6d9e3a80eeb1bd8b7e4b28385;
  key made by `bun run rotate-attestor`, secret never printed; settings now
  checked per feature (503 misconfigured) so challenge and discovery work
  while others are unset; live smoke test of challenge, discovery, login, 404
- Why this way: test app on NEAR testnet and App Attest development mode
- Importance: first live backend the iOS app can call
- Metadata: apps/api/wrangler.toml, apps/api/scripts/rotate-attestor.ts; 2026-11-08
- Gaps: APP_ID (Apple Team ID), TREASURY_CONTRACT, PORTAL_ORIGIN, MAIL_FROM and
  the RESEND_API_KEY secret are unset
  (staging/beta/prod now point at this worker via ce2c60a)

## 2026-11-08 - Step RunnerGateway

- Item: RunnerGateway package (ORDER §12 client half + Joel's device-proof path)
- What it is: typed gateway to apps/api — challenge, device registration,
  claim-pass request with nested attestation decode, merchant discovery by
  geohash cell. Injectable HTTPTransport seam; live URLSession transport plus
  scripted mock in RunnerGatewayTesting. Typed GatewayError with server
  status + machine-readable code envelope.
- How it was done: research-first (API.md contract + routes/runner.ts as the
  wire truth), TDD with Swift Testing (9 tests, red then green), local skills
  test-driven-development + write-swift + api-and-interface-design auditing
- Why this way: gateway owns URL + codec only; App Attest bytes and NEAR
  signatures arrive as strings from the platform/wallet layers, so key
  material never crosses this box. Matches the server's snake_case wire
  exactly, including the nested attestation JSON string.
- Importance: the missing client Joel's iPhone proof needs; unblocks device
  registration + 2.5 km claim-pass run once APP_ID is set
- Metadata: packages/RunnerGateway (+Testing), iOS 26 + macOS 15; 2026-11-08
- Gaps: live calls unverified (APP_ID still unset server-side); no app-layer
  wiring yet — App Attest generation, NEP-413 signing, Keychain storage land
  with RunnerAuth + app target

## 2026-11-09 - Step RunnerNear (holy grail package)

- Item: RunnerNear package — passkey-only NEAR client + provider, Rust core via UniFFI
- What it is: single Swift box for all NEAR needs. `runner-near-core` (Rust:
  NEP-413 digest, ed25519, implicit accounts today; near-api RPC + MPC signer
  next) exposed through UniFFI as a checked-in 29 MB XCFramework with
  generated bindings isolated in `RunnerNearCore`. Swift owns passkey login
  (`Auth0PasskeyProvider`: PKCE authorize, code exchange, refresh, logout),
  MPC signing (`FastAuthSigner`: NEP-413 via core + relayer request), session
  and account models. No social login, no JS toolchain in the binary.
- How it was done: research-first (Peersyst `providers/javascript` +
  `sdks/browser` + `@shared/core` read; JS tree audited and rejected for
  shipping — same 7 deps in both packages, no platform fit). Rust toolchain
  installed (1.99.1 + iOS targets), crate TDD'd with `cargo test` (5 tests:
  server-minted NEP-413 vector, RFC 8032, round-trips), then Swift Testing
  (17 tests: 6 live-core vectors, 7 provider state machine, 4 signer shape).
  Testnet values baked from docs (shared Auth0 client, contract IDs).
- Why this way: Swift does login + orchestration, Rust owns every chain
  byte; byte-exact NEP-413 with `apps/api` proven both sides of the wire.
  Passkey-only scoping collapses the port to one login path + three
  signature methods. Generated code never mixes with hand code.
- Importance: the `RunnerAuth` base — app-layer auth builds off this box only
- Metadata: packages/RunnerNear (rust/, Sources/RunnerNearCore|RunnerNear|
  RunnerNearTesting, Frameworks/RunnerNearCoreFFI.xcframework 29 MB,
  rust/build-xcframework.sh); uniffi 0.32.2; iOS 26 + macOS 15; 2026-11-09
- Gaps: near-api RPC + MPC `SignerTrait` + live relayer/account-resolver
  implementations need testnet proof (relayer URL + response shape unverified
  — mocked); passkey sheet presentation + Keychain land with app layer;
  binary size to re-measure when near-api lands

## 2026-11-09 - Step RunnerNear RPC + MPC pipeline

- Item: near-api RPC, tx builders, MPC derivation + signature ceremony
- What it is: Rust core gains `NearRpc` (blocking JSON-RPC: latest block,
  access keys, view calls, broadcast), unsigned tx builders (transfer +
  function call, V0 Borsh), hash/attach with wrong-key rejection, and
  `mpc_public_key` view helper. Swift gains the ceremony: per-signature
  Auth0 round trip with payload param, `fatxn` assertion fail-closed,
  `guard_id` corrected to `jwt#https://<domain>/`, resolver
  (`path → derived key → implicit account`), `SignSubmitter` seam.
- How it was done: protocol docs read first (contracts, how-it-works,
  sign-transactions, relayer); live testnet probes before baking anything
  (`derived_public_key` needs explicit predecessor + `domain_id: 1` for
  Ed25519 — verified, not assumed). Rust `cargo test`: 10 offline + 3 live
  `#[ignore]` (latest block, stable Ed25519 derivation, unknown-key error).
  Swift: 26 tests, 5 suites, green. Fixed along the way: modulemap
  `framework module` → `module`, legacy bindgen backend dropped for
  `uniffi-bindgen-swift`, SystemConfiguration/Security linker settings,
  deployment-target env for Rust builds.
- Why this way: no tokio crosses the FFI (blocking reqwest); near-api
  supplies chain types only, so encoding bugs are upstream's. The `sign`
  call submission stays behind `SignSubmitter` — production is a controlled
  relayer, testnet proof runs through the core with a dev key in scratch.
- Importance: everything short of the interactive JWT is proven against
  live testnet; the ceremony's first real login is now a device step
- Metadata: packages/RunnerNear; XCFramework 65 MB (near-api aboard —
  watching); uniffi 0.32.2; iOS 26 + macOS 15; 2026-11-09
- Gaps: interactive passkey login + `sign` submission + account
  funding/key-permission proof need a device (JWT-gated, can't run
  headless); production submitter (server relayer) is a later step

## 2026-11-09 - Step RunnerNear simulator ceremony proof

- Item: interactive passkey login + signing JWT, proven live on the booted
  iPhone 18 Pro sim (DEBUG harness, out of git)
- What it is: two-phase login → signing consent over a 1-yocto
  self-transfer, `fatxn verified` on an RS256 JWT, derived implicit account
  `81bff4edb4f1d84629218de49a42aaa003730a0e599bed0d26cdf3c41ed2f383`
  with key `ed25519:9jVMuq…`; live RPC confirms the key absent
  (`unknown_access_key` @ block 276938107 — unfunded, as expected
  pre-faucet)
- How it was done: tenant Auth0 Action read line-by-line; four contract
  corrections fell out — payload as comma-joined bytes (not base64), no
  `audience` on plain login, signing JWT arrives as `access_token` (no
  `id_token`), `fatxn` is a bare number array. Temporary localhost-capture
  hack until the `applinks` universal-link callback lands. Swift suite 31
  tests, green
- Importance: closes the RPC + MPC pipeline's last gap — the ceremony's
  first real login is done, on live testnet
- Metadata: apps/ios/Runner proof harness (DEBUG-only, out of git);
  2026-11-09
- Gaps: faucet-fund the derived account, MPC `sign` + broadcast the dust
  tx, production relayer submitter

## 2026-11-09 - Step RunnerNear 1Click intents rail

- Item: cross-chain entry/exit for escrow + treasury without new cryptography
- What it is: `intents.rs` in the Rust core — blocking 1Click client over
  official `one-click-sdk-rs` contract types (pinned rev `f9741c3`): token
  list, dry/wet quotes, deposit notices, status polls with `X-API-Key`.
  Swift gains `IntentFunctions` seam, `LiveIntentClient`, `MockIntentClient`.
- How it was done: SDK endpoint fns never attach partner auth (verified in
  source), so transport stays in our blocking client — no tokio crosses the
  FFI. Stringly enums fail closed (`EXACT_INPUT`, `ORIGIN_CHAIN`, …).
  Rust: 6 offline tests against a local mock server (auth-header presence,
  dry-no-address, submit→status round trip, 401 mapping). Swift: 4
  `IntentTests` (dry→wet→submit→SUCCESS, terminal FAILED, unscripted
  fail-closed). Suites: 16 Rust + 35 Swift, green.
- Why this way: deposits stay plain transfers (MPC-signed, already built);
  INTENTS-balance swaps are one NEP-413 signature (already built). No new
  signature machinery — solvers do the rest. Confidential swaps deferred:
  unlinkability fights the attestation model; one flag away when wanted.
- Importance: the money-movement half of item 9; escrow funding and
  withdrawals ride this rail
- Metadata: packages/RunnerNear (rust/intents.rs, IntentFunctions,
  LiveIntentClient, MockIntentClient, IntentTests); XCFramework 67 MB;
  2026-11-09
- Gaps: live mainnet proof needs small-amount swaps (no intents testnet);
  1Click API key provisioning; NEP-413 intent signing needs mainnet tenant
  confirmation

## 2026-11-09 - Step RunnerAuth (identity box)

- Item: ORDER 9a — Apple + NEAR identities, Keychain session, coordinator
- What it is: `RunnerAuth` depends on `RunnerNear` (first package→package
  link). `AppleAuth` (nonce, identity-token parse/validate, no UI),
  `SecureStore` seam + `KeychainStore` (device-only, no sync, silent) +
  `MemoryStore` mock, `RunnerAuthCoordinator` actor (Apple-first ordered
  linking, single `runner.account.v1` blob, NEAR optional per F11).
  NearLink carries stored credential only — expiry/refresh stay with
  RunnerNear’s provider, nothing poses as a fresh session.
- How it was done: research-first (SDK headers ground truth, sosumi.ai for
  HIG + Callback docs, Auth0.swift as reference-not-dependency).
  Presentation stays app-layer; deprecated `callbackURLScheme` init never
  enters the package. TDD Swift Testing: 11 tests, 3 suites, green —
  incl. a live Keychain round trip with per-run service + cleanup.
  Concurrency: async store seam (sync witnesses satisfy, actor mock
  conforms) per swift-concurrency-expert.
- Why this way: chain signing programs against RunnerNear’s `NearSigner`;
  the day-3 local-key fallback lands as a `LocalKeySigner` with no
  app-layer changes. No Auth0.swift dependency — auditable boxes only.
- Importance: the identity half of item 9; app container builds on this
- Metadata: packages/RunnerAuth (RunnerAuth, RunnerAuthTesting); first
  inter-package dependency (`../RunnerNear`); iOS 26 + macOS 15; 2026-11-09
- Gaps: `credentialState` launch check + controller presentation live in
  the app layer; no server SIWA verification exists or is planned — the server trusts App Attest + key ownership only; biometric gate on the device-key item (sessions stay silent)

## 2026-11-09 - iOS UI design (Figma)

- Item: zero-functionality UI for the iOS app
- What it is: Figma file https://www.figma.com/design/3pOXDAoe1amTH89MBf2ymP with
  12 screens (ready, countdown, live, summary with claim pass, history, places,
  claim amount, claim done, wallet with goal lock and pool, PacePilot opt-in,
  fund the pool, lock a goal), local tokens (12 colors, radii, spacing) and
  components (button, chip, stat, tab bar, status bar, toggle, start button,
  live pulse, beat, countdown)
- How it was done: built through the Figma plugin API; looping motion with
  Smart Animate between component variants (start breathes, live dot pulses,
  beat dots tick at running cadence, countdown 3-2-1, toggle slides); click-
  through prototype with flows "Run and claim" and "Wallet, goals and pool"
- Why this way: Peter asked for UI first with no functionality, polished and
  motion focused; dark premium look from his reference sites
- Importance: visual target for the SwiftUI screens
- Metadata: Inter stands in for SF Pro in Figma (SF Pro is not installed on the
  Windows design machine); the app should use the system font; headings use
  Instrument Serif (OFL); 2026-11-09

## 2026-11-09 - Goal escrow contract + run proofs

- Item: ORDER §10 and §13 goal escrow (G01-G05)
- What it is: NEAR contract in contracts/escrow. Runners lock their own token
  on a distance or distance-and-time goal; a server-signed run proof that beats
  it unlocks into an escrow balance they can withdraw or lock again; give up
  sends half to the treasury. runner-api now returns run_proof with each pass.
- How it was done: near-sdk 5.30.1, 18 unit tests with real ed25519 proofs;
  cargo near build in the pinned image, wasm 198,631 bytes, sha256
  0e8c0771...3b5c8132; server test for the proof shape and signature (43 pass)
- Why this way: one attestor key, kept apart by shape (deny_unknown_fields +
  kind) so a claim pass can never unlock a goal; no pause or admin withdraw so
  runners always control unlocked money; failed pool transfers are retryable
- Importance: last money path in the spec
- Metadata: contracts/escrow, apps/api/src/attestor.ts, design/API.md; 2026-11-09
- Gaps: not deployed; run proofs only exist for runs that pass the claim rules
  (2.5 km+, steps, 4 hour gap), so a second run within 4 hours cannot unlock a
  goal yet

## 2026-11-09 - Ije logo

- Item: app name and logo
- What it is: name Ije (Igbo for journey), agreed with Peter. Lowercase "ije"
  wordmark in even rounded strokes; the dots over i and j are two runners
  passing, the j dot in gold. Files in design/brand: app icon (SVG, PNG 1024
  and 512, ivory on ink #1C1813), wordmark dark and light (SVG and PNG)
- How it was done: hand-built SVG geometry, rendered to PNG with headless Chrome
- Why this way: simple vector mark that stays sharp at any size and matches the
  ivory, ink and gold palette in the Figma file
- Importance: needed now for the NEAR auth production access application
- Metadata: design/brand; 2026-11-09

## 2026-11-09 - Gas relayer (NEP-366)

- Item: POST /v1/relay so runners never hold NEAR for gas
- What it is: the app sends a SignedDelegateAction signed with the runner's
  full access key; the server checks an allow-list (treasury claim, escrow
  unlock/give_up/withdraw/lock_from_balance/flush_pool, token ft_transfer_call
  to escrow or treasury), exact deposits, a 100 Tgas cap, the delegate
  signature and key, nonce and expiry, App Attest and a 30 per hour limit, then
  wraps it in a transaction signed by RELAYER_ACCOUNT_ID and sends it
- How it was done: small borsh encoder/decoder for the two NEAR types needed
  (no runtime dependency); byte-for-byte checked against @near-js/transactions
  2.5.1 in tests (dev dependency only); 17 new tests, 60 in total
- Why this way: deposits stay with the runner so the contracts' 1-yocto
  full-access rule still means the runner approved the move; the allow-list
  stops the relayer paying for anything else
- Importance: closes Peter's open item for RunnerEscrow's submitter
- Metadata: apps/api/src/nearTx.ts, src/routes/relay.ts, migrations/0002; 2026-11-09
- Gaps: not deployed; needs the relayer account, its key as a secret, the
  contract and token ids, and migration 0002 applied to D1

## 2026-11-10 - One attestor for treasury and escrow

- Item: Peter's request that one DAO vote changes the attestor everywhere
- What it is: the treasury holds the only attestor key and exposes it with a
  public get_attestor view. The escrow stores no key; unlock checks the proof
  locally, reads the key from the treasury, and verifies the signature in a
  callback that re-checks the lock before paying. The escrow depends on the
  treasury, not the other way round.
- How it was done: Peter's suggestion over a first push-based version (which
  needed the treasury to know the escrow and a resync path); cross-contract
  view + private callback; treasury and escrow unit tests in the pinned
  cargo-near image
- Why this way: one vote, no stored copies that can drift, no linking step at
  deploy; unlocks are rare so the extra hop is cheap; goal escrow funds stay in
  their own contract apart from the pool (ORDER items 9 and 10)
- Importance: governance of the attestor now covers the whole money system
- Metadata: contracts/treasury, contracts/escrow, design/API.md; 2026-11-10
- Gaps: release wasm build needs a rerun on a machine with free memory; deploy
  order is treasury, then escrow with treasury_id

## 2026-11-10 - Treasury on Sputnik DAO

- Item: ORDER �14 (item 8 read as funds in a Sputnik DAO)
- What it is: contracts/treasury reworked into a claims module. The pool lives
  in a Sputnik DAO v2; the module is the only member of a "claims" role allowed
  to add and approve Transfer proposals (1-of-1), so a valid claim adds and
  approves a DAO payout in one transaction. Council (both members) governs all
  else. Escrow gains pool_id (the DAO) for the give-up share. Relayer gets
  per-method gas caps (claim 200 Tgas) and DAO donations via ft_transfer.
- How it was done: approval and execution rules checked against
  near-daos/sputnik-dao-contract source (policy.rs proposal_status: any role
  reaching its threshold approves; approved proposals execute in the same call
  and return the bond). Tests: claims module 21, escrow 22, API 65, all pass.
- Why this way: runners still claim instantly while the money and all admin
  sit in a standard Sputnik DAO that Trezu can manage; the claims role cannot
  do anything but payouts that already passed the module's checks
- Importance: meets the "Treasury on Sputnik/Trezu" requirement
- Metadata: contracts/treasury, contracts/escrow, apps/api/src/routes/relay.ts,
  design/API.md (policy JSON and deploy order); 2026-11-10
- Gaps: not tested against a live Sputnik DAO yet (needs the testnet account);
  release wasm builds still to run; Peter's RunnerEscrow needs pool_id in
  EscrowDeployment

## 2026-11-10 - Figma redesign pass 2

- Item: UI polish from Peter's references, Mobbin and Pinterest
- What it is: ivory editorial theme with dark live, countdown and claim
  screens; photos on start (dawn runner), summary (shoes, "Fastest 5K this
  month" badge) and places (nearest spot card); claim pass moved off the
  summary hero into the small banner; one escrow card in the wallet (total,
  goal in progress, ready to move); bold distance and "Slide to finish" on the
  live run; floating dark pill tab bar; serif headings with one italic word
- How it was done: Figma Plugin API from the signed-in browser console (the MCP
  connection hit the Starter plan limit); photos generated in Gemini, stored in
  design/photos and loaded into Figma from the public repo
- Why this way: luxury and editorial references lead with photos, warm neutrals
  and serif type; Peter asked for a less obtrusive claim pass and a single wallet
- Importance: visual target for the SwiftUI screens
- Metadata: https://www.figma.com/design/3pOXDAoe1amTH89MBf2ymP, design/photos; 2026-11-10

## 2026-11-12 - v1 accounts live

- Item: runner-api moved onto Peter's v1 contracts
- What it is: DAO ije-v1.sputnik-v2.testnet, claims module ije-v1-claims.testnet,
  escrow ije-v1-escrow.testnet, relayer ije-v1-relayer.testnet. Attestor
  public key is now ed25519:6hzVqMovzZJKF28grcG1wM8iuoLHsNdTPKDxoWDhZEH3; the
  2026-11-08 key ed25519:5nkc2Npp... is retired and nothing checks it
- How it was done: Peter made a new attestor key and set ATTESTOR_SECRET_KEY at
  the v1 deploy (2026-11-10 22:25 UTC); DAO proposal 1 set the policy with
  snake_case permission labels, council *:Finalize and a fixed 3-vote community
  rule; proposal 2 set the claims bond to 0.1 NEAR; proposal 3 added merchant
  mamaput.testnet; worker version 89709716 points at the v1 accounts
- Why this way: proposal 0 used labels Sputnik does not match and would have
  locked the DAO; an empty group with quorum 0 counts as approved on Finalize,
  so the default vote policy has quorum 1
- Importance: Peter's e2e passed on these accounts (claim paid the merchant,
  escrow unlock credited the balance)
- Metadata: apps/api/wrangler.toml, design/DEPLOY.md; 2026-11-12
- Gaps: proposal 0 still holds 1 NEAR until it expires and someone Finalizes it

## 2026-11-12 - RunnerUI design package

- Item: shared brand, fonts and colors for the SwiftUI screens (Peter's ask,
  modelled on wades-app packages/ui)
- What it is: packages/RunnerUI with Theme.Colors (ivory light look and night
  dark look; the live, countdown and claim screens set the dark scheme),
  Theme.Typography (Instrument Serif headings, system font body and metrics,
  `.runnerText(...)`), Theme.Spacing, Radius, Sizing, Elevation
  (`.runnerShadow(...)`), Theme.Brand and IjeWordmark, and `.pill(...)` buttons
- How it was done: colors, sizes, tracking, radii and the tab bar shadow read
  from Figma pass 2 through the plugin API; Inter in Figma stands in for the
  system font; Instrument Serif Regular and Italic bundled from google/fonts
  with OFL.txt and registered at first use
- Why this way: same three-tier token setup as wades-app, so screens never use
  raw colors or sizes
- Importance: base for every screen in the UI phase
- Metadata: packages/RunnerUI, design/brand; 2026-11-12
- Gaps: not compiled yet (no Swift toolchain on the Windows machine); Peter
  needs to run `swift test` in packages/RunnerUI and add the package to
  apps/ios/Runner.xcodeproj

## 2026-11-12 - Run Ready screen, first pass

- What it is: the signed-out SwiftUI landing screen, based on Figma's
  01 Run - Ready frame, with first-run and sample-history Xcode previews.
- How it was done: reused RunnerUI and the existing dawn photo, added
  screen-local distance selection and a Start action seam, and opened
  the screen directly from the app root.
- Why this way: running has no account prerequisite, and the previews
  can render both states without a database or network connection.
- Importance: establishes the visual starting point of the run flow.
- Gaps: workout start and other tabs need their destination flows.
  Exact Figma comparison and accessibility verification are pending.

## 2026-11-12 - Run Ready frame refinement

- Selected Figma frame 5:3 and verified its 402 × 874 dimensions.
  Matched the Start ring, four distance options, and last-run card more
  closely. The history preview uses the reference greeting and date.
- Added custom distance entry with locale-aware numeric validation.
  The app still opens without authentication.
- Rendered the history preview at standard size and AX 5. At accessibility
  sizes the chips stack and the decorative, unwired tab strip is hidden.
- Pixel-level comparison, custom distance interaction verification, and
  wiring the workout and tab destinations remain open.

## 2026-11-12 - Run Ready hero and distance input

- Blended the hero image into the status-bar background and added press
  feedback to the four distance chips.
- Moved Custom distance into a native sheet with numeric validation and
  Cancel and Set distance controls. Verified the sheet opens in the iPhone
  simulator. Saving an entered value still needs runtime verification.
- Rebuilt the app and rendered the updated history preview in Xcode.

## 2026-11-12 - Run Ready distance verification

- Matched the reference date order in the history preview and refined
  spacing and typography around the distance options and tab strip.
- On the iPhone 18 Pro simulator, entered and saved 7.5 km. The sheet
  dismissed, Custom became selected, and Start displayed 7.5 km.
- Xcode rendered the updated Ready preview. Exact pixel alignment with
  Figma remains open.

## 2026-11-12 - Ready card uses saved runs

- Reads the most recent run from the shared local SwiftData store when
  the scene becomes active. The card formats distance, elapsed time and
  average pace from the saved measurements.
- A missing distance leaves distance and pace unavailable. A storage
  error reports that history is unavailable without opening another store.
- Verified clean launch with an empty local store in the iPhone simulator.
  The populated Xcode preview uses the same formatting with sample data.

## 2026-11-12 - Last-run detail action

- Added the View action from the Ready frame. It opens a native sheet
  with the saved run's date, distance, elapsed time and average pace.
- The action is available when a saved run exists. At accessibility text
  sizes it moves below the metrics so its label can scale.
- Verified that the action renders in the populated Xcode preview.

## 2026-11-12 - Ready weather, custom distance, and navigation

- Ready can show local Apple Weather with attribution after the runner
  enables location access. WeatherKit must be enabled for the signed app ID.
- Custom distance uses native wheels for 1–100 and km/mi, with a warm
  gradient sheet and a Confirm action. The selected unit stays on the
  Start label, and the start action receives kilometers.
- Ready shows All caught up when there are no saved runs. The last-run
  card uses lighter metrics. The Start ring now meets the outside edge.
- The native tab bar groups Run and Goals with prominent PacePilot on
  iOS 27. On iOS 26 all three use standard tabs. Community is at the top
  and groups Places and community funding for their later screens.
- Pulling beyond the bottom reveals View all, arms History with a
  haptic, and opens the sheet on release. The entry is also tappable.
  History uses local runs and supports Back and native sheet dismissal.
- Verified the empty-state pull, Back, and custom wheel confirmation
  on the iPhone 18 Pro simulator. Live WeatherKit requires a signed test.

## 2026-11-12 - Ready tab palette correction

- Kept Run and Goals together and PacePilot separate, with the original
  dark surfaces, gold selection, and muted inactive items.
- Uses branded controls over SwiftUI TabView selection so the palette and
  placement are consistent on iOS 26 and iOS 27.

## 2026-11-12 - Native Ready toolbar and tabs

- Moved the branded Community pill into a native top toolbar item.
- Restored the native SwiftUI tab bar and iOS 27 prominent PacePilot tab.
  The bar requests the dark brand background and gold tint. On the tested
  simulator, Liquid Glass resolves those surfaces to gray with white items.

## 2026-11-12 - Ready header and tab refinement

- Restored the inline date, weather, and Community layout and the dark,
  gold, and muted tab palette after reviewing the system toolbar rendering.
- Community uses a solid heart badge. PacePilot combines a running figure
  and a sparkle and announces itself as an AI run coach to VoiceOver.

## 2026-11-12 - Interactive Ready to History transition

- Ready shows No activity yet in Instrument Serif when there are no runs.
  The entry has no directional icon and remains available as a button.
- The History page tracks the upward pull continuously. Crossing the
  threshold requests haptic feedback and releasing settles the page with a
  spring. Short pulls return to Ready. Back and a downward pull from the
  History header dismiss it.
- Ready scales and dims behind the moving page. With Reduce Motion on,
  the page fades and Ready stays at its original scale.
- When revising a referenced screen, preserve its approved components and
  use only the cues explicitly requested for a new gesture.

## 2026-11-12 - History entry simplified

- Removed the custom slide, its gestures, and its haptic. The last-run
  card has a View all action at the top right that pushes History through
  the Run tab's NavigationStack. The empty state is static text.

## 2026-11-13 - Branded startup and optional weather

- Startup shows the RunnerUI wordmark while checking location permission.
  An undecided permission opens the native iOS prompt directly.
- Once allowed, location and Apple Weather have a five-second startup
  deadline. Ready shows weather and attribution only after success.
- The Runner target uses IjeIcon.icon as the installed app icon.
- Verified on the simulator that the native prompt opens and Ready loads
  without a weather row when Apple Weather is unavailable.

## 2026-11-13 - SwiftUI shell and Ready organization

- RootView renders RootNavigation and delegates startup and run history
  to models created by AppViewModels. WeatherKit I/O lives in RunWeatherService.
- Home owns tab selection through HomeTab. Run owns typed push and sheet
  routes, and Ready composes separate hero, distance, and history views.
- The debug Ready preview switches between demo, worst-case, and empty
  fixtures. Large text exposed a squeezed weather label, so the fallback
  header stacks at accessibility sizes. Metrics stack when the row does
  not fit.
- Verified simulator startup with live weather, rendered the worst-case
  preview, and passed 24 iOS tests.

## 2026-11-13 - Home page routing

- AppRouting defines HomeNavigation and the typed Community and History
  destinations. Root owns the router and Home renders its NavigationStack.
- Both destinations are pushed pages with standard iOS Back navigation.
  The distance picker remains local presentation state in Ready.

## 2026-11-13 - Resolve weather before leaving splash

- Splash resolves location first, then waits for WeatherKit to return
  current conditions or an error before routing to Ready. The five-second
  limit applies to finding a location, so a late fix no longer cuts the
  WeatherKit request short.
- Verified both the no-location fallback and live conditions with a
  simulated Lagos location on the iPhone simulator.

## 2026-11-13 - Run countdown

- Start opens the Countdown page through the typed Home router. It counts
  3–2–1 and hands the selected distance to the workout callback.
- The Figma night palette, gold numeral, circle, and Get set heading use
  RunnerUI tokens. The subtitle reports whether PacePilot is on or off.
- PacePilot defaults to off until the app has an opt-in setting. The
  workout screen remains a separate integration.

## 2026-11-13 - Run Live screen

- Countdown replaces its route with Live and preserves the selected distance.
  Live uses the reference's dark metric layout, goal progress, and bottom controls.
- The PacePilot card contains its on status and four sequentially pulsing dots.
  Reduce Motion keeps the dots still.
- The production route displays an elapsed timer and unavailable metrics until
  sensor services are integrated. The Xcode preview uses the Figma sample values.

## 2026-11-13 - Run Summary

- Finishing Live replaces it with Summary through the Home router.
  NavigationStack provides the Back button to Ready.
- Summary uses the Figma photo and metric layout. The shared claim banner
  shows ready or low community balance and hides at the signed expiry.
- Both funded and low-balance states rendered in Xcode. Run sensor data,
  claim issuance, and DAO balance are separate integrations.

- Summary's achievement badge uses the filled bronze star from the Figma reference.

## 2026-11-13 - PacePilot opt-in

- The prominent PacePilot control presents the Figma opt-in content as
  a full-screen cover. The toggle is the sole preference control and saves
  immediately. A standard Close control dismisses the cover.
- Countdown and Live use the saved preference. It defaults to off.

## 2026-11-13 - Run History

- History follows the Figma personal-best cards and month-grouped run
  rows. The sand-circle Back button pops the existing Home stack.
- The page reads the saved history already loaded for Ready. The 5K and
  10K cards use matching recorded distances because split data is absent.
- Verified the iPhone simulator build and populated Xcode preview.

- History now uses the system inline title and Back button, matching Run Summary.

- Ready's last-run card and each History row open the selected saved run
  in Summary through the Home navigation stack. View all opens History.
  Saved summaries use the recorded date, distance, and elapsed time.

## 2026-11-13 - Splash handoff

- Keep Home mounted behind the opaque splash so the native tab and
  navigation containers can lay out before they become visible.
- Three recorded iPhone simulator launches from a terminated process
  showed Home fading in at full size without the top-left expansion.

## Fitness engine integration

- Live uses RunnerSession for active time and manual pause, resume, and finish.
  RunnerLocation and RunnerCadence supply the measured metrics. Pause stops the
  sensor streams and resume starts a fresh GPS segment.
- RunnerStore commits the completed run locally before Summary opens. A draft
  keeps the run ID, elapsed time, distance, and finish reason until the history
  commit succeeds, so recovery can safely retry the same run after termination.
- The iOS integration test covers manual transitions, reopening the on-disk
  store, and recovering an interrupted run once. Device sensor verification
  and Apple Health workout export remain open.
- The run model owns periodic checkpoints and saves once more when the app
  backgrounds. Recovery no longer depends on the Live screen's refresh timer.
- The location integration test feeds two GPS segments around a pause and
  checks that only their measured distance reaches the saved run.
- A newly completed Summary offers explicit Apple Health export after the
  local commit. RunnerSession carries pause intervals to the existing
  HealthKit builder, and HealthKit sync IDs use the same run ID for retries.
  Export is available from the immediate Summary and needs a device check.
- Session tests verify the exact pause intervals passed to HealthKit, including
  a run finished while paused. Xcode confirmed the installed export build
  launches on the connected iPhone 16 Pro.
- The simulator UI check exercised Countdown, Live, pause, resume, Finish,
  Summary, and History. The same 0:34 run reopened in History after a full
  process restart. Physical movement, lock-screen recording, and the Apple
  Health write still require the iPhone check.
- Device feedback: retain the last measured cadence in new run history,
  preserve old records with a lightweight migration, derive current pace
  from timestamped GPS deltas when speed is missing, and display average
  pace in min/km. Give Last Run more clearance above the tab bar.
- Summary now offers one Apple Health connection for future manually
  finished runs. The system controls Health permissions, and interrupted
  run recovery writes only to Runner history.
- Pace on the Ready card, History, and Summary always renders minutes and
  seconds, including paces over an hour per kilometer. Live average pace
  retains its whole-minute min/km display.
- An iOS regression test verifies that Apple Health opt-in survives rebuilding
  the run model, only an opted-in finish reaches the Health gateway, and
  interrupted and pre-opt-in runs remain in local history.
- The simulator cadence regression sends a measured 158 spm through the
  cadence tracker, finishes while paused, and checks Summary and History.
- Average pace now truncates to whole minutes and caps the displayed value
  at 120+ min/km across Live, Ready, History, and Summary. Live current pace
  keeps minutes and seconds.
- Summary reads Apple Health workout authorization immediately and refreshes
  on activation. The connection row combines that permission with Runner's
  automatic-export opt-in.
- Ready moves Start up 8 points and tightens the gaps above Last Run so
  the card clears the floating tab bar sooner. Summary uses a 24-point
  Apple Health icon beside its label.
- Live current pace displays a dash above 120 minutes per kilometer.
  Average pace continues to display 120+ min/km above the same threshold.
- The iPhone field retest confirmed that Live displays a dash for very slow
  current pace and a newly finished run appears automatically in Fitness
  after Apple Health is connected.

## Workout Live Activity

- Runner starts an iPhone HealthKit workout session when Apple Health is
  connected. RunnerSession still owns workout state and local history.
  In-app pause, resume, and finish drive the system session.
- A local WidgetKit extension displays the run timer and measured distance
  on the Lock Screen and the run timer in Dynamic Island. It uses RunnerUI
  typography and colors and exposes no workout controls.
- The navigation stack cannot pop an active Live route. Finishing still
  replaces Live with Summary, where the native back navigation is available.
- The iOS simulator suite passed 37 tests, including the route guard.
  On-device activity rendering and gesture behavior remain to be verified.
- ActivityKit updates carry the timestamp of the state snapshot. A late
  distance update from before Pause cannot overwrite the paused display.
- The run integration test verifies the ordered HealthKit gateway lifecycle
  for an opted-in run and confirms recovery does not start a system workout.
- The iPhone retest confirmed that the Live Activity appears on the Lock
  Screen and Dynamic Island, freezes on Pause, and disappears on Finish.
  Swiping back during the run leaves Live on screen.

## PacePilot live audio

- Runner links the existing rules and scheduler to the opted-in countdown
  and active workout. The first slice speaks distance and goal marks,
  stopped and low-battery nudges, and shows the measured coaching state.
  Pausing or finishing cancels pending speech.
- PacePilot uses on-device Apple speech and prefers the highest-quality
  installed English voice, with a Premium voice first and the device
  locale breaking quality ties. iOS manages speech audio and ducking.
- The next PacePilot slice unlocks after ten locally saved, user-finished
  runs strictly longer than 2.5 km. The ten latest qualifying runs supply
  a median cadence target when measurements exist. The coach shares a
  playback slot between speech and a short alternating step pattern,
  which stops repeating once cadence is within the target band.
- Playback on a locked iPhone and music ducking require a device check.

### Countdown playback and preview

- PacePilot and the pre-run screen share one countdown sequence. Each number
  gets at least one second, and the next number or the run starts after
  the current cue finishes. Leaving either screen cancels its own playback.
- Play countdown in PacePilot previews the same three spoken cues without
  changing the coaching preference or starting a workout.

## Encounters wiring

- One shared EncounterTracker per launch snapshots counts at run start
  and diffs at finish into RunSummary.encounters, so the ledger survives
  pause and resume. Tracking runs only when Bluetooth permission is ready.
  No view changed; the summary card already rendered the slot.
- The buzz is a fixed double-double notification pulse with no intensity
  grading. Sightings still pass the grader as a throttle only.
- The scanner and advertiser build their CoreBluetooth managers on first
  start, not in init, so app boot and test hosts never touch Bluetooth
  hardware. This mirrors LiveLocationUpdateSource, whose hardware comes
  up in start().

## 2026-11-13 — Kokoro voice benchmark (PacePilot screen)

- Item: two buttons on the PacePilot opt-in screen benchmark the bundled
  Kokoro-82M CoreML checkpoints (FP16 325 MB vs INT8 83 MB) on the same
  coaching cue, "Nice and steady. Settle into your rhythm." Each button
  unpacks its model on first tap (timed), synthesizes (timed), plays the
  audio through the existing CoachAudioPlayback path, and reports load /
  synth / audio seconds plus real-time factor. Later taps reuse the loaded
  model, showing warm times; audio quality is judged by ear.
- What it is: `packages/RunnerKokoro` (actor `KokoroBenchmarkService`,
  offline load via speech-swift `fromPretrained`, per-variant serial queue
  so blocking CoreML calls never stall the cooperative thread pool);
  `PacePilotOptInPage` gains a `KokoroBenchmarkSection` with two
  `KokoroBenchmarkRow` views; models ship as two zips in
  `Runner/Resources/KokoroModels/` (LFS-tracked) unpacked to Application
  Support on first use, because Copy Bundle Resources flattens
  same-basename files and the two variants share every filename.
- How it was done: repos cloned from HuggingFace and LFS-pulled locally;
  `RunnerKokoro` wraps speech-swift (pinned revision) + ZIPFoundation as a
  local package following the repo's flat-package convention; verified by
  the Runner-scheme app build and `swift test` in packages/RunnerKokoro.
- Why this way: zips keep the bundle collision-free and preserve the exact
  HF layout the SDK expects; the SDK (Apache-2.0) does G2P, chunking and
  vocoding instead of reimplementing the pipeline.
- Importance: lets Peter decide on-device whether the 83 MB INT8 model
  sounds as good as the 325 MB one before committing PacePilot to either.
- Metadata: packages/RunnerKokoro, PacePilotOptInPage, project.xcproj
  (RunnerKokoro product, 2 resource entries), .gitattributes (LFS);
  2026-11-13
- Gaps: Mac e2e numbers only (FP16 RTF 3.41 vs INT8 RTF 0.77 on M4 Pro);
  on-device ANE numbers pending Peter's run. `swift format` compliance not
  re-checked from the sandbox. RunnerTests target still lacks a development
  team, so build-for-testing fails (pre-existing, untouched).

## 2026-11-13 — Kokoro compute-unit fallback (device MPSGraph failure)

- Follow-up: both buttons failed on-device at first load — iOS 26's GPU
  compiler (MPSGraph, `MPSReorderOperations`) rejects a transpose in the
  model graph (`axes in perm tensor must be unique`). macOS accepts the
  identical bytes, so this is device-OS codegen, not file corruption:
  the bundled zips round-trip byte-identical (sha256 matches the HF LFS
  oid) and synthesize fine from the unzipped bytes.
- `KokoroBenchmarkService` now loads with `all`, then falls back to
  `cpuAndNeuralEngine`, then `cpuOnly` (`firstSuccessful`, unit-tested).
  The result line reports which units ran (`all`/`ane`/`gpu`/`cpu`), so
  the INT8-vs-FP16 comparison stays on equal hardware.
- Metadata: packages/RunnerKokoro, PacePilotOptInPage metrics line;
  2026-11-13
- Gaps: fallback verified by unit tests + Mac e2e only; the true test is
  Peter's device re-run (expect `ane` or `cpu` in the result line).

## 2026-11-13 — Kokoro trial prediction per unit (load succeeded, inference failed)

- Follow-up: device log showed `Loaded Kokoro E2E model` / `model loaded
  successfully` BEFORE the MPSGraph errors — CoreML compiles GPU programs
  lazily, so load succeeding proves nothing. The per-unit attempt now runs
  a trial synthesis (`hello`) and only accepts a unit that predicts; the
  trial also warms the model, so timed synth numbers are steady-state.
  Upstream has no newer export (both SHAs match), so fallback stands.
- Metadata: packages/RunnerKokoro `loadFromDirectory`; 2026-11-13
- Gaps: device re-run still pending; expect `ane` or `cpu` in the line.

## 2026-11-13 — Kokoro locked to CPU (background constraint)

- Peter: the coach speaks from the background, where the GPU is off, so
  inference must be CPU — which is also why this is CoreML. Fallback list
  is now CPU-only; the line still reports `cpu` for the record.
- Metadata: packages/RunnerKokoro `unitFallbacks`; 2026-11-13

## 2026-11-13 — Audio session off main thread (benchmark findings)

- Peter's device findings: cold load ~10s FP16 / ~9s INT8 (one-time unzip
  + CoreML compile), warm synth ~1s for 3.4s audio on both — speed is a
  wash on CPU, so the pick is quality-by-ear plus size (83 vs 325 MB).
- Fixed the `AVAudioSession ... main thread` warnings his log showed:
  `CoachAudioPlayback.play` now applies/releases the session on a
  detached background task; engine start/stop stay on main. Covers the
  countdown and benchmark paths, and coaching later.
- The boot-UUID/linguisticdata lines in his log are harmless OS noise.
- Metadata: CoachAudioPlayback.swift; 2026-11-13

## 2026-11-13 — TTS decision: Kokoro INT8 (83 MB)

- Peter's verdict after on-device comparison: both voices sound the same,
  so the 83 MB INT8 model wins outright over the 325 MB FP16 one.
- Next: wire live coaching to INT8 and drop FP16 from the bundle.
- Metadata: decision only, no code change; 2026-11-13

### Run controls and PacePilot UI cleanup

- The live finish control completes a run on a full slide and offers
  an accessible Finish run action. Ordinary taps on the track no
  longer open a confirmation dialog.
- PacePilot opt-in shows the coaching settings without the temporary
  model audition controls now that voice comparisons are complete.

## 2026-11-13 — Kokoro INT8 wired into live coaching

- Peter chose INT8: same voice as FP16 on the cues, quarter of the space,
  ~2s faster cold start. FP16 removed from the bundle (INT8 zip only);
  live coaching now speaks through it with Apple speech as fallback.
- What it is: `KokoroCueRenderer` (app layer, `@MainActor`, no shared
  mutable state) tries Kokoro then falls back to `SystemSpeechRenderer`
  per cue; countdown cues never speak anywhere — the 3-2-1 is visual only
  (`RunCountdownPage` ticks, `playCountdown` lost its coach arg).
  Brain spells out every spoken number (`SpelledOutNumber`, en_US), e.g.
  "Kilometer one. Your average pace is six minutes and twenty seconds
  per kilometer." `RunCoach` preloads the ~9s cold load at countdown
  entry and run start without blocking either; cancelled at run end.
  Opt-in page demos the two audition sentences with timing.
- Why this way: backgrounded apps get no GPU, so CPU-only; the model
  stays loaded for the run, so only the first cue could wait — and the
  earliest cue fires minutes in. Preload handle is a stored Task,
  cancelled in `end()`; concurrent loads serialize on the service actor.
- Importance: first on-device verdict loop closed (user compared voices);
  iPhone 14 + locked-screen playback still needs Peter's field check.
- Metadata: KokoroCueRenderer.swift, RunCoach, RunCountdownPage,
  PacePilotOptInPage, SpelledOutNumber, RulesCoachBrain + tests,
  project.xcproj (INT8 zip only); 2026-11-13
- Gaps: first-cue latency and locked-screen playback unverified below
  iPhone 16 Pro — needs the iPhone 14 field run.

## 2026-11-13 — Kokoro out of git, into E2E

- Per Peter: the Kokoro benchmark does not live in git. The entire
  `RunnerKokoro` package plus the INT8 zip moved to `apps/ios/E2E/`
  (gitignored, on-disk only like the other harnesses); the project
  references them via `../E2E/` paths. Code stays imported by the app
  target as before; fresh clones build without the voice and fall back
  to Apple speech. LFS config removed — nothing left to track.
- Metadata: apps/ios/E2E/RunnerKokoro, apps/ios/E2E/KokoroModels (zip
  only), project.xcproj; 2026-11-13

## 2026-11-13 — Kokoro split: production into PacePilot, benchmark stays E2E

- Per Peter: the benchmark must not live in git, and the non-benchmark
  voice code belongs in the PacePilot package. Split accordingly.
- `KokoroBenchmarkService` (+ variants, errors, load/synth/unload) moved
  to `RunnerPacePilot` with its speech-swift/ZIPFoundation deps; the app
  imports it from there. `apps/ios/E2E/RunnerKokoro` keeps only the
  timing struct, the `run()` harness and its tests, depending on the
  PacePilot package by path. E2E is gitignored; fresh clones build and
  fall back to Apple speech.
- Noted: a peer rewrote PacePilotOptInPage mid-task; the audition section
  was re-added on top of their version, otherwise untouched.
- Metadata: RunnerPacePilot (service + tests), E2E/RunnerKokoro,
  project.xcproj; 2026-11-13

### Encounter and PacePilot integration audit

- Live shows measured encounter totals. Finished runs persist all three
  counts in run history using an additive SwiftData migration. Older
  records keep their existing data and have no encounter measurements.
- Encounter startup rolls back on scanner failure. Bluetooth manager
  callbacks and lifecycle calls share main-actor isolation, and pauses
  reset continuous dwell timing. A stationary Core Location update no
  longer contributes distance.
- PacePilot keeps the countdown visual. Opted-in runs begin loading
  Kokoro INT8 during countdown. Apple speech handles cues while the
  model is loading, on unsupported phones, and when synthesis fails.
  Model extraction is staged and concurrent requests share a load.
- The local model archive stays under ignored E2E. The synchronized
  folder lets Xcode include it when present and build without it.

### Core Bluetooth startup crash

- Pass each restoration delegate into its Core Bluetooth manager initializer.
  iOS checks for the restoration callback during initialization. Delegate
  callbacks use the manager passed to them so they can handle startup events
  before the stored manager reference is assigned.
- The physical-device regression test starts and stops the live encounter
  tracker with both Core Bluetooth managers.

## 2026-11-13 - Mainnet v1 deployment (chain + worker)

- Item: live mainnet stack under `codez2.near`
- What it is: developer account funded with 17.93 NEAR; subaccounts
  `ije-v1-claims/escrow/relayer/seeder.codez2.near` (4 / 5 / 0.5 / 0.5);
  DAO `ije-v1.sputnik-dao.near` via factory with boot council
  (`codez2.near`, `ije-joel.near`), runner policy enacted by 2-of-2 vote
  (council/community/claims, 0.1 N bond); treasury `84c58ba7` and escrow
  `77a525b5` deployed with mainnet init args (Circle USDC 17208628...6a1c331a1,
  DAO pool, 0.005 seed, $5 min-lock); DAO/claims/escrow registered on USDC;
  worker `4fd0459c` at 100% with production attestation, mainnet RPC, fresh
  `runner-api-mainnet` D1, mainnet secrets
- How it was done: near-cli-rs from the user's Terminal (keychain signing),
  verification by RPC after every step, reproducible release builds
- Why this way: DEPLOY.md order; each account pays its own storage;
  server keys are fresh full-access keys, owner keys never leave the keychain
- Importance: mainnet is live except the DAO USDC pool, deliberately left
  empty so no payouts run until funded; escrow works standalone
- Metadata: apps/api/wrangler.toml, apps/api/package.json,
  apps/api/scripts/dao-policy.mainnet.json; 2026-11-13

### Goals UI

- Goals replaces the Wallet entry with an empty state, an unbeaten goal
  card, and completed goals with funds ready to move. Only an unbeaten
  goal blocks creation of another goal.
- Lock a goal uses the shared Home distance wheel and a native numeric
  input for custom amounts. Funding carries the selected goal into the
  chain selector and sample NEAR Intents quote.
- The sample action exercises the locked state for the current app
  session. Previews cover empty, unbeaten and beaten goals. No NEAR
  calls or deposits are made.

- The Goals action and floating tab bar share one bottom inset in Home.
  Stacking them there keeps the full button visible and tappable.

- Goals previews cover unlocked funds with and without an unbeaten goal.
  A Withdraw button belongs to each unlocked goal and displays its return
  chain and address before tapping. Preview withdrawal only changes
  sample state. Returning to a non-NEAR funding chain needs a separate
  outbound route when escrow is connected.

- The funding quote requires a return address entered through a native
  text prompt for the selected network. The shortened address reopens the
  prompt when tapped. Done remembers the return address per network on
  the device for the next funding flow. Lock goal opens a medium deposit sheet with
  the large amount, separate network label, copyable sample address, and
  a short exchange note. The header has extra top padding. Done closes
  the sheet and advances to the sample locked goal.

- Goals uses the shared funding quote card and deposit sheet. Each
  feature supplies its labels, amounts, address, and actions so Community
  can reuse the views with a different recipient.

### Recorded kilometer splits

- Live runs estimate each completed kilometer crossing between consecutive
  location fixes on the active workout clock. Paused time is excluded.
- Split durations travel with workout checkpoints and saved run records.
  The immediate summary and History read the same durations. Earlier
  records migrate with empty splits because they only contain totals.

### Goals loading skeleton

- While Goals loads for the first time, a placeholder goal card shows grey
  bars for the eyebrow, amount, target and footnote. It replaces the
  "Loading goals" spinner. It uses SwiftUI's placeholder redaction on the
  card's own layout and pulses unless Reduce Motion is on. VoiceOver reads
  it as "Loading goals". A refresh after the first load keeps the last
  goals on screen instead of showing the skeleton again.
- The Goals column fills the screen width in every state. Before, the
  unavailable and loading states had no full-width card, so the page
  shrank to its text and showed white strips at the sides.
- Previews now cover Loading and Unavailable.

### Goal attempts and unlock status on the goal card

- The "On a goal" card shows the best run on this device since the goal
  locked ("Best try: 1.02 km in 14:32"). The progress bar fills by
  distance covered, then by the time limit scaled to that distance; a
  full bar means the goal is met.
- Every Goals refresh, including pull to refresh and opening the page,
  lists the goals, then checks a saved run against the locked goal with
  the Worker only (a run proof, no chain transaction). A proven goal shows
  as "Ready to withdraw"; otherwise the reason shows under the best try. The outcome is one of: the last run can't count (the run check's
  reason, for example missing kilometre splits), no recent run beats the
  goal, or the run wasn't verified (Motion & Fitness off, cadence outside
  the limit, or the Worker's eligibility code).
- Withdraw does all the chain work, one contract call per stage, and each
  stage first checks the chain so a repeat tap resumes where it stopped:
  `unlock` with the cached proof only while the lock is in `get_locks`
  (seeding first, idempotent); reserve the payout (the Worker returns the
  same reservation); `withdraw` only while `get_balance` still covers the
  amount. Each call is atomic on chain, and a failed USDC transfer is
  re-credited by the escrow callback.
- The Withdraw button names the stage it is on: "Requesting withdrawal"
  (unlock), "Reserving payout", then "Processing deposit" (escrow
  `withdraw`), and refreshes when done. Leaving mid-way is safe: the next
  tap resumes at the unfinished stage. While 1Click delivers a payout, the
  Goals page refreshes every 15 seconds until the goal ends and leaves.
- RunnerEscrow decodes the deployed `get_locks` shape, where `id` and
  `created_at` are U64 strings.
- The run check gives a reason instead of silently dropping a run, and the
  latest rejection is kept so a later refresh can show it.

## 2026-11-14 - Goal escrow wiring

- What it is: the non-UI wiring behind Goals. One 1Click client, one thin
  Worker proxy, one saved quote per goal, withdrawal from the goal ID, and
  RunnerEscrow restored as the escrow seam.
- How it was done:
  - RunnerNear builds and decodes 1Click quotes with the pinned SDK's
    `oneclick` v0 models, which carry `customRecipientMsg` and
    `depositMemo`. `ProxiedIntentClient` posts the SDK bytes to
    `/v1/intents/*` with an App Attest assertion over
    `METHOD /v1/intents<path> <sha256(body)>`. Goals and Community share it.
  - The Worker proxy checks App Attest and a route allowlist (`POST
    /v0/quote`, `GET /v0/tokens`, `GET /v0/status`). It adds the 1Click key
    and returns the upstream status and body.
  - A payable quote whose recipient is the escrow is a goal quote. It must
    be `EXACT_OUTPUT` into escrow USDC, and its msg must be the deployed
    `DepositMsg { owner, goal, funding_id }`.
  - D1 keeps one row per goal ID. Concurrent requests share the first
    upstream quote. An identical retry gets the saved body back, even if
    the deadline moved. A different request for the same ID returns 409.
    The return address is not unique, so a runner can reuse it.
  - Done closes the deposit sheet. `/v1/goals/list` links a goal to an
    escrow lock from `get_locks` only once 1Click reports SUCCESS for that
    goal's deposit address. The lock must also match the goal, the quoted
    amount, and be created after the quote. An abandoned quote with the
    same goal therefore never takes the paid goal's lock. Only locked
    goals are returned; nothing shows while a deposit is pending.
  - The deployed `goal_funded` event is not read. It costs no contract
    storage (logs live in receipt outcomes), so it stays as an on-chain
    record of `funding_id` to lock.
  - `/v1/goals/withdraw` takes the goal ID. It requires the lock to be gone
    and the escrow balance to cover the locked amount, which is what
    actually landed (no fee). It then reserves one 1Click payout back to
    the saved return address on the original chain and registers USDC
    storage for the payout account. The app signs escrow `withdraw`
    through RunnerEscrow and relays it on `/v1/relay`.
  - A goal ends when 1Click reports SUCCESS for its payout: the list drops
    it and keeps no history on screen, so the runner can lock a new goal. Before that, the escrow balance decides: still holding
    the amount means `ready_to_withdraw` (resume), already sent means
    `withdrawing`, so a settled goal never falls back to withdrawable while
    1Click picks up the deposit. The Goals page shows
    "Withdrawn".
  - iOS splits the old GoalService into `GoalAccount` (implicit key, App
    Attest, NEP-413 signing, delegate relay as `EscrowSubmitter`),
    `GoalService` (list, quote, withdraw, attest, unlock) and
    `GoalEvidence` (run candidates and proof cache, moved unchanged).
- Why this way: these are exactly the five requested behaviours. The
  previous pass had two transports, a separate fund route, a ticket table,
  archival transaction lookups and a 409 for concurrent quotes; all removed.
  Goal state is read from the chain (locks, balance) and 1Click status
  instead of tracked transaction rows.
- Importance: the only paths that move user funds are now small enough to
  review in full.
- Metadata:
  - Worker goal code is 377 lines, previously 884.
  - Migration 0005 drops the empty 0004 goal tables (0004 is applied on
    mainnet D1; 0005 is not applied yet).
  - The escrow source in this tree builds byte-identical to the deployed
    `ije-v1-escrow.codez2.near` (code hash
    HAWyNfaRsXVdbzn9tpYBqqiC4XksbTmcWpNNkFNoh4Wg).
  - NEAR RPC is `rpc.mainnet.fastnear.com` for the Worker and the app;
    `rpc.mainnet.near.org` returned HTTP 429 to the Worker's shared
    Cloudflare egress, which surfaced as "Goal status is unavailable".
  - Tests: Worker 79, RunnerNear Rust 17 and Swift 43, RunnerEscrow 19,
    RunnerGateway 17, app 41.
  - Not exercised on a device or with real funds.
