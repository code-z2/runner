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
