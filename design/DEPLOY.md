# Testnet/Mainnet deployment order — v1 (DRAFT for review)

Goal: a live testnet/mainnet stack the app can run against end to end (seed → run →
claim pass → relayed claim → escrow lock/unlock), without touching the
production names (`*.ije.near`, `ije.sputnik-dao.near` stay reserved).

## Versioning rule

Every testnet/mainnet deployment is suffixed: `ije-v1-*`. A breaking contract or
policy change mints `v2` accounts; we never redeploy over a versioned name.
`v0` (`ije-claims.testnet`, …) is the pre-handoff install — superseded, left
alone for reference. The worker keeps one live `[vars]` set; only one
version serves traffic at a time.

v1 accounts:

| Role | Account |
| --- | --- |
| DAO | `ije-v1.sputnik-v2.testnet` (from `sputnik-v2.testnet` factory, name `ije-v1`) |
| Claims module | `ije-v1-claims.testnet` |
| Goal escrow | `ije-v1-escrow.testnet` |
| Relayer | `ije-v1-relayer.testnet` |
| Seeder | `ije-v1-seeder.testnet` |
| Token | `3e2210e1184b45b64c8a434c0a7e7b23cc04ea7eb7a6c3c32520d03d4afcb8af` (existing testnet USDC) |

## Order

### 0. Prereqs (no chain writes)

- [ ] `near-cli-rs` logged in on testnet/mainnet with the deployer key (faucet-funded).
- [ ] Contracts build reproducibly: `cargo build -p treasury -p escrow --target wasm32-unknown-unknown --release`; record both wasm hashes in the appendix.
- [ ] Confirm factory `create` args + deposit against `sputnik-v2.testnet` at execution time (shape: `create(name, policy)`; testnet faucet covers the deposit).

### 1. Create + fund v1 accounts

- [ ] Create the four `ije-v1-*` accounts via faucet (`near account create-account fund-myself … use-faucet`), ~10 N each to start.
- [ ] Save each full-access key; relayer + seeder keys become worker secrets later.

### 2. Create the DAO

- [ ] `near contract call-function … sputnik-v2.testnet create` with name `ije-v1`, council `[peter, joel]` (boot policy).
- [ ] Record the DAO id; fund it with ~5 N (proposal bonds + storage).

### 3. Enact the runner-governed policy (before claims: sets the 0.1 N bond)

- [x] DAO created: `ije-v1.sputnik-v2.testnet` (8 N), council `[ije-dev.testnet, ije-dev2.testnet]`, factory boot policy, DAO full-access public key `ed25519:J7cKGyBLfrKPtZz3McHPbKN9C5FLS1cUoEbfBQLCJoXF`.
- [ ] Fill [`apps/api/scripts/dao-policy.json`](/Users/peter/Developer/runner/apps/api/scripts/dao-policy.json) placeholders: council = ije-dev + ije-dev2 testnet accounts, claims group = `ije-v1-claims.testnet`.
- [x] Proposal 0 (`ChangePolicy`, 1 N bond attached) submitted by `ije-dev.testnet`; our council vote cast (`HLPpdoAm…`, votes `[1,0,0]`) — SUPERSEDED, do not approve.
  Joel caught a lock-up: Sputnik permission/vote-policy labels are snake_case
  (`call`, `policy`, `add_member_to_role`, `remove_member_from_role`; only
  `transfer` was right — verified against the deployed DAO wasm). Our file used
  PascalCase everywhere, so council + community would have matched nothing; with
  no `all`/Everyone role left, nobody could ever propose a fix.
- [ ] Let proposal 0 expire (7-day boot window to ~Nov 17). Proven: early `Finalize`
  is rejected on-chain (`ERR_UNSUPPORTED_ROLE`, tx `6PMu92…`); removal needs Joel's
  second vote and he chose expiry, so hands off. No v2 DAO: the DAO is healthy,
  proposal 1 proceeds in parallel, only 1 N parks until expiry.
- [x] Joel posted proposal 1. Validated: snake_case labels throughout
  (`call`/`policy`/`add_member_to_role`/`remove_member_from_role`/`transfer`,
  matching the DAO wasm Display arms); roles council/community/claims with the
  right groups; community fixed-count rule (quorum 3, threshold weight 3);
  council keeps `*:Finalize`; bond 0.1 N. Our approval cast (`CNnfkX…`, votes `[1,0,0]`).
- [x] Proposal 1 APPROVED (council `[2,0,0]`) → runner-governed policy enacted: community/council/claims, 0.1 N bond. Joel voted.
- [x] Proposal 2 (FunctionCall: claims `set_proposal_bond` → 0.1 N) submitted; our vote cast (`F8yy7Z…`, `[1,0,0]`).
- [x] Proposal 2 APPROVED (council `[2,0,0]`) → executed; claims `get_config` confirms bond 0.1 N. Chain side fully aligned.
- [ ] Joel's draft MUST keep a Finalize path (e.g. council `*:Finalize`): without the
  boot policy's `*:Finalize`, nobody could finalize 0's expiry after enactment and the 1 N parks forever.
- [ ] After expiry (~Nov 17), anyone finalizes proposal 0 → Expired, 1 N bond returns to `ije-dev`.
- [ ] Verify: `get_policy` shows community / council / claims roles, bond 0.1 N.

### 4. Deploy the claims module

- [x] Deployed + init `new` (bond 1 N = current DAO bond; `set_proposal_bond` to 0.1 N after enactment).
  Verified: `get_seeder` → v1 seeder / 0.005 N / enabled; `get_config` → DAO/token/attestor/unpaused. (`get_attestor` view returns `{}` — key confirmed via `get_config`.)
- [ ] Deploy wasm to `ije-v1-claims.testnet`, init `new` (REPLACED — done above):
  `dao_id=ije-v1.sputnik-v2.testnet`, `token_id=<testnet USDC>`,
  `attestor_public_key=ed25519:6hzVqMovzZJKF28grcG1wM8iuoLHsNdTPKDxoWDhZEH3` (fresh v1 key, same format as `rotate-attestor.ts`),
  `units_per_cent="10000"`, `proposal_bond="100000000000000000000000"` (1 N = current DAO bond; `set_proposal_bond` to 0.1 N after enactment),
  `seeder_account_id=ije-v1-seeder.testnet`, `seed_amount="5000000000000000000000"` (0.005 N).
- [ ] Fund the module with ~3 N bond float (0.1 N per concurrent claim × headroom).

### 5. Deploy the goal escrow

- [x] Deployed + init `new`; verified `get_config` (DAO owner, $5 min_lock, correct treasury/pool/token).
- [ ] Deploy wasm to `ije-v1-escrow.testnet`, init `new` (REPLACED — done above):
  `owner_id=ije-v1.sputnik-v2.testnet` (DAO-governed),
  `token_id=<testnet USDC>`, `treasury_id=ije-v1-claims.testnet`,
  `pool_id=ije-v1.sputnik-v2.testnet`, `min_lock="5000000"` ($5, 6 decimals).

### 6. Token registration

- [x] `storage_deposit` done for DAO, claims, escrow (paid by `ije-dev.testnet`).

### 7. Fund the seeder

- [x] Seeder holds 10 N faucet funds (testnet target met, no transfer needed). Relayer holds 10 N; worker keys added to both.
- [ ] Transfer ~100 N DAO → `ije-v1-seeder.testnet` (REPLACED — superseded by decision: 10 N testnet / 1 N mainnet).
- [ ] Verify onchain: `get_seeder` on the claims module returns the v1 account, amount, `enabled: true`.

### 8. Deploy the worker

- [x] `wrangler.toml [vars]` → v1 accounts.
- [x] Secrets set: `SEEDER_SECRET_KEY` + `RELAYER_SECRET_KEY` (fresh v1 keys), `ATTESTOR_SECRET_KEY` (fresh v1 key).
- [x] Secrets RESET (2026-11-11): first upload embedded a truncated pubkey half
  (off-by-one in the composing script, `slice(9)` on an 8-char prefix) → live
  `relayer_key_invalid` on seed+claim. Recomputed with the repo's own
  `parseRelayerKey` rules (64 bytes, pubkey re-derives), uploaded via
  `wrangler secret bulk`. On-chain keys were always correct; no rotation needed.
- [x] `APP_ID = "QHUBYNZ482.io.wades.ije"` (Team ID + bundle ID = App Attest RP ID). Live seed route answers past settings gate (`invalid_account_id` on empty body).
- [x] Bundle ID → `io.wades.ije` (`project.xcproj`, JSON config); `appleAudience` follows.
- [x] `wrangler deploy` → version `8c3129c5` (2026-11-10).
- [x] `bun run migrate:remote` (2026-11-11): live D1 was missing 0002/0003,
  so `POST /v1/seed` 500d after auth on the `seed_log` insert. 0003 applied
  (0002 already live); tables verified: challenges, devices,
  attested_activities, relay_log, seed_log. Lesson: my `head`-truncated
  `wrangler whoami` hid a valid login — check full output before declaring
  auth dead.

### 9. Verify end to end (testnet/mainnet)

- [ ] Views: `get_attestor`, `get_seeder`, `get_config` on both contracts.
- [ ] `POST /v1/seed` a fresh implicit account → `{seeded: true, tx}`; repeat → `{seeded: false}`.
- [ ] Register device → finish a 2.5 km+ run → claim pass → `POST /v1/relay` claim → `succeeded`; runner auto-joined to `community`.
- [ ] Escrow: `ft_transfer_call` lock → `unlock` with run proof → `give_up` split (needs test USDC — see open questions).

## Roll-forward

New breaking change → new suffix (`v2`), repeat steps 1–9, flip worker `[vars]`, retire the old version only after the app build pointing at it is gone.

## Appendix — v1 record (fill at execution)

- wasm hashes: claims `afe8fde6841264a086cdf6fea7c840ab8d4573ffbc3c81f5748a0b9530a2688d`, escrow `e134d6c2f0ae6f1f5bf45f9c23a47bd9d95517ee85000bef05129ac3c3da786a` (built 2026-11-10, `cargo build --release --target wasm32-unknown-unknown`)
- DAO id, creation tx: …
- Worker version hash: `a7a07613` (2026-11-11, APP_ID set; supersedes `8c3129c5`)
- Dummy merchant: `mamaput.testnet` created + registered on test USDC.
  Proposal 3 (FunctionCall: claims `add_merchant mamaput.testnet`, 0.1 N bond)
  submitted, our vote cast (`2VEvRM…`, `[1,0,0]`) — Joel approved → `Approved`
  `[2,0,0]`; `is_merchant mamaput.testnet` returns true on-chain.
- Runner `19d36e…541a3`: seeded (0.005 N), registered on USDC, holds exactly
  5.000000 USDC from `ije-dev.testnet` (ft_transfer verified on-chain).
- Claims deploy: init ok; `get_seeder` + `get_config` verified
- Escrow deploy: `get_config` verified
- DAO proposal 0: ChangePolicy, our vote cast, awaiting `ije-dev2`
- Blockers carried: APP_ID (Team ID), Joel's second vote
- Seeder funded tx: …

## Decided (2026-11-10 review)

1. Seed amount: 0.005 NEAR fixed.
2. Escrow `owner_id`: DAO.
3. Test USDC: official Circle testnet/mainnet USDC; 20 USDC in `ije-dev.testnet` seeds merchant/lock flows.
4. Attestor: fresh v1 key (format-compatible with `rotate-attestor.ts`).
5. `min_lock`: $5 (`"5000000"` base units).

Seeder float: testnet starts 10 N from v1 faucet funds (≈2,000 seeds); mainnet starts 1 N of real money (≈200 seeds), topped up from DAO revenue before wider use.

## Fund flow — every account that must hold money on mainnet

Proven on testnet 2026-11-11 (device e2e: seed → claim → DAO auto-approval →
escrow lock → unlock → withdraw). Proposal 4 on the testnet DAO is dead history —
council cleans it up in Trezu; it needs no code or worker action.

Testnet names on the left, mainnet role on the right. Amounts are floors and
alert thresholds, not targets — top up from the ops treasury before alerts fire.

## 1. DAO USDC pool (payout liquidity)

- Testnet: `ije-v1.sputnik-v2.testnet`, funded once with 20 USDC from
  `ije-dev.testnet`. Claim 150 USDC-cents auto-approved and paid
  `20 → 18.50`, no council vote.
- Mainnet: the Sputnik DAO must hold enough USDC to cover peak outstanding
  fitted-run claims. Formula: `pool ≥ 7-day payout run-rate × 2`.
- Alert when pool < 3 days of run-rate. Top-up is a plain `send-ft` from ops.

## 2. Relayer NEAR float (gas for every relayed tx)

- Testnet: `ije-v1-relayer.testnet` (`RELAYER_SECRET_KEY`). Pays gas for
  `relay` calls: claim proposals, escrow unlock/withdraw relays, registrations.
- Mainnet: fund with NEAR, alert at 5 NEAR, top up from ops. Each relayed tx
  costs thousandths of a NEAR; the risk is outage by a thousand small cuts,
  so alert on balance, not per-tx cost.
- `SEEDER_SECRET_KEY` account only signs seeds — needs ~0.05 NEAR for its own
  storage, then never moves money.

## 3. User onboarding float (account creation + first storage)

- Runner keychain accounts must NEVER hold user funds (design invariant), but
  each fresh account costs storage staking at creation (~0.5 NEAR on mainnet
  rates at time of writing — re-check at deploy).
- The seeder pays account creation on registration. Budget
  `new-users-per-month × creation-cost × 1.5`, held in the seeder account,
  alert at 1 month of runway.
- USDC `storage_deposit` (~0.00125 NEAR each, one-time): the escrow contract,
  the DAO, and every merchant must each be registered on the USDC NEP-141
  contract before first receipt. Runner accounts never touch USDC directly.

## 4. Escrow contract NEAR buffer (state storage, not deposits)

- Testnet: `ije-v1-escrow.testnet`. Locks hold user USDC; the contract itself
  needs NEAR only for its own state growth (each lock record).
- Mainnet: pre-fund escrow with a storage buffer (start 2 NEAR, alert at 0.5).
  If `lock` ever requires attached storage instead, that comes from the
  relay, never from the user's keychain account.
- `panic="abort"` is removed from both escrow and treasury release builds
  (done 2026-11-12, takes effect on next redeploy): it turned a
  one-character arg-shape bug (`lock_id` as number vs string) into a silent
  trap. Diagnosability is a funding issue — every failed relay burns relayer
  gas with no error string.

## 5. Claims contract NEAR (storage + view-call staking)

- Testnet: `ije-v1-claims.testnet`. Holds no USDC — payouts come from the DAO
  pool (§1). Needs its own NEAR only for storage staking and attestor config.
- Mainnet: 0.5 NEAR, no alert needed; it cannot drift.

## 6. Ops treasury (the funder of everything above)

- Testnet: `ije-dev.testnet` — funded the DAO (20 USDC), repaid itself on
  withdraw, ended whole.
- Mainnet: one multisig-held account that tops up §1–§4. Its own balance is
  the single dashboard number: DAO pool + relayer + seeder-onboarding +
  escrow buffer.

## 7. Intent path (mainnet-gated design step, not testnet)

- Deposit: external wallet → NEAR Intent (1Click/solver) → escrow deposit.
  The intent settles directly to escrow; the keychain account only signs the
  lock call, never custodies.
- Payout: `unlock` → intent → external address. Withdraw target is set at
  lock time and is never the keychain account.
- Budget: solver/filler fee spread per intent + a 1Click API key (without one,
  an extra 25 bps applies to every non-`ANY_INPUT` quote). Hold the fee float
  in ops, accounted per-payout.
- Until the intent path ships, mainnet stays closed: the keychain-never-holds
  invariant cannot be kept with direct transfers at production scale.

## Monitoring minimum

| Signal | Alert when | Pager |
| --- | --- | --- |
| DAO USDC pool | < 3 days run-rate | ops |
| Relayer NEAR | < 5 NEAR | ops |
| Seeder onboarding float | < 1 month runway | ops |
| Escrow NEAR buffer | < 0.5 NEAR | ops |
| Failed relay rate | any sustained > 0 | eng |
