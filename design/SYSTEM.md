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
