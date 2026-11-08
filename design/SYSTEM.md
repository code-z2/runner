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
