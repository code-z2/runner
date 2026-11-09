# Agent Rules

## Discuss then build

For each item, discuss look and behave first. Complete only as agreed.

## Document every completion

After each work or feature, add an entry to design/SYSTEM.md with:
what it is, how it was done, why it was done that way, its importance, and any metadata.
No item counts as done without this entry.

## Tooling

Default to `bun` for JS/TS work (`bun install`, `bun run <script>`,
`bunx <bin>`). No `npm`/`npx` unless bun cannot do the job.

## Swift toolchain

Swift 6 language mode on the newest Xcode toolchain (6.4+;
`SWIFT_VERSION` stays `6.0` — the compiler accepts nothing newer).
Packages declare `swift-tools-version: 6.4`.
iOS 26.0 is the minimum deployment target; always build with the
latest SDK (27.x).

## Skills precedence

Prefer repo-local skills first (`.agents/skills/`, `.claude/skills/`),
then global/user-scope skills. A repo skill covering the task wins over
an outside equivalent; reach outside only for what no local skill covers.

## Format before push

Run `swift format` before every push; pushes are
blocked by a local pre-push hook (`format:check`) when unformatted.
Never push with `--no-verify`.

## Git hygiene

`node_modules/`, `.wrangler/`, `dist/`, `.dev.vars`, `*.db`,
`__pycache__/` are gitignored — never force-add them. Commit lockfiles
(`bun.lock`); never commit two lockfiles for one package.

## Think Before Coding

No silent assumptions. State what you're assuming. Surface tradeoffs. Ask before guessing. Push back when a simpler approach exists.

## Simplicity First

Minimum code that solves the problem. No speculative features. No abstractions for single-use code. If a senior engineer would call it overcomplicated — simplify.

## Surgical Changes

Touch only what you must. Don't "improve" adjacent code, comments, or formatting. Don't refactor what isn't broken. Match existing style.

## Goal-Driven Execution

Define success criteria. Loop until verified. Don't tell Claude what steps to follow, tell it what success looks like and let it iterate.

## Destructive filesystem ops (mv, rm, overwrite)

1. Commit a safe point first, then request approval — no exceptions.
2. List the target directory before the op; never assume names are free.
3. One op per command. Verify between steps (`ls` after each move).
4. Prefer non-destructive forms: `cp` + verify + `rm`, or `mv -n` (no-clobber).
5. Never chain two dependent moves in a single command.

## Client patterns (vaariance/wades-app)

Source of truth: `vaariance/wades-app`, branch `dev`, `apps/ios/Wades`. Every iOS change follows these.

- Composition root: one `AppModel` builds the long-lived services once (gateway, storage, auth, integrity, toast, feedback) and hands them down by init injection. No god-object view model. No singletons except what App Intents needs (`AppDependencyManager`).
- Root routing: an `@Observable RootNavigation` holds a `RootRoute` enum. Feature shells use `SubNavigation<Edge, Destination>`: at most one edge underlay plus a typed push `path`. `open(_:)` is the only programmatic entry; dismiss through bindings or `path`, never a second close API.
- View model graph: `AppViewModels` creates each feature view model lazily and wires its callbacks there, never in `RootView.body`.
- Feature layout: `Features/<Name>/{Model, Store, Service, ViewModel, View/{Pages, Rows, Sections}}`. Cross-feature pieces live in `Shared/<Area>`.
- View models: `@Observable final class` conforming to `AppViewModelType` (`ModelWithStore`, `ModelWithLifecycle`). They hold account-wide data and operations only, as `private(set)` state. Each screen owns its own interaction state as `@State`. Dependencies are optional with defaults so previews build. Feedback goes through `any Feedback` (`NoFeedback` default) and toasts through `ToastController`.
- Async freshness: a `@ObservationIgnored` generation counter so an older response never overwrites a newer one. Failed reads keep the last known data.
- Stores: `nonisolated` `Sendable` structs over `any Storage` drawers (`DurableStore` Keychain, `DefaultsStore`, `CacheStore`, `DiskStore`). Computed properties with `nonmutating set`. Keys live in a `private enum Key`, prefixed with the domain (`"names.primary"`). Local data renders before network reads land.
- Packages hold platform-neutral logic; the app target holds SwiftUI and wiring only.
- Views use design tokens (`Theme.Spacing`, `Theme.Colors`) and a text-style modifier, never raw sizes or colors.
