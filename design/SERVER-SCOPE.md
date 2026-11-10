# Server scope: seeding + runner-governed DAO

For Joel — one package covering ORDER [8a](ORDER.md) (runner-governed DAO) and [8b](ORDER.md)
(seeding). App side (local key, delegates, views) is tracked separately; this doc is backend-only.

## Context (verified in-repo)

- Relayer exists (`apps/api/src/routes/relay.ts` + `relay.test.ts`): NEP-366 delegates, App Attest,
  per-method gas caps, allow-list already covers `claim`, escrow `unlock`/`flush_pool`/`give_up`/
  `withdraw`/`lock_from_balance`, token `ft_transfer_call` (escrow) and `ft_transfer` (DAO donation).
- Treasury module exposes `get_attestor()` (`contracts/treasury/src/lib.rs:269`); escrow reads it per unlock.
- Missing: everything below. No seed endpoint, no seeder config, no membership flow, no DAO policy change.

## 1. Seeder

- Plain NEAR account, DAO-capitalized once (suggest 100 NEAR ≈ 20,000 seeds at 0.005). Key in Workers secret.
- `POST /v1/seed` in `{ "account_id", "key_id", "assertion", "near_public_key", "near_signature" }`.
  Guards: App Attest device check (clientData `seed:<account_id>`) plus a key-ownership proof — an
  ed25519 signature of `seed:<account_id>` that must verify against a pubkey whose implicit
  derivation equals the account. No SIWA session exists server-side (removed from scope — see below);
  the device binding plus key ownership is the anti-farm unit (replay is harmless: seeding the
  rightful account is idempotent). Behavior: `view_account` → exists returns `{ "seeded": false }`;
  missing transfers a fixed 0.005 NEAR, awaits commitment, returns `{ "seeded": true, "tx" }`.
  Status is 200 with the body in both cases (idempotent by design); the gateway decodes on 200.
  Rate limit 5/hour per device. Env: only `SEEDER_SECRET_KEY` — account and amount come from
  `get_seeder`, so rotation is one vote.
- Idempotent by existence check; double-seed harmless (no locking). `503` when funder dry/RPC down;
  app falls back to showing the fundable address.
- Claim path guarantees seeded before attesting (same internal function, no extra app call).
- Tests: extend the `relay.test.ts` pattern — missing account seeds, existing skips, dry funder 503s,
  unauthenticated 401s.

## 2. Seeder config on the treasury module (mirrors `get_attestor`)

- New view `get_seeder() -> { account_id, amount, enabled }`. Server reads it per request, same as
  escrow reads the attestor — one vote rotates or kills seeding everywhere, no deploy, no secret ceremony.
- Rotation = vote to point at a fresh funded account. Emergency cutoff = vote `enabled: false`;
  existing users unaffected (their accounts already exist).
- Keep the hot float small with alerted top-ups from a DAO-held reserve; the seeder key is the one
  hot secret in this design.

## 3. Auto-join on claim (ORDER 8a)

- Claims module proposes `AddMemberToRole` (community) on first successful claim; bond from the
  module's own NEAR float (bonds recycle on finalization — working capital, not spend).
- DAO policy JSON: `community` role (all claiming runners; policy kinds only, genesis majority of votes
  cast at 5% quorum, 7-day window); `council` (Peter + Joel, unanimous: pause module + `RemoveProposal`
  inside the window only); `claims` role keeps 1-of-1 transfer approval and gains membership proposals.
- Until this ships, the item-8 council policy stands.

## Deploy checklist

- [ ] Seeder capitalized; module bond float funded (separate line items).
- [ ] Balance alert at 20% seeder runway; seed-vs-claim rate monitor (gap means farming or broken clients).
- [ ] AASA + Auth0 callback already live for `ije.wades.io` (prior handoff).
- [ ] Testnet faucet documented for the permissionless path; mainnet fallback = self-fund.

## Scope note: no server-side SIWA

There is no SIWA session or Apple verification on the server and none is planned — device Apple
Sign-In stays as the client identity root, but the server trusts only App Attest + key ownership.
Every "SIWA" guard in this doc means exactly that.

## As built (this handoff implements it)

- Treasury contract: `get_seeder`/`set_seeder` (DAO-gated), `joined` set + `is_member` view, auto-join
  chain on first successful claim (membership proposal + approval nested in the approval callback),
  `AddMemberToRole` proposal kind with the exact Sputnik JSON shape (covered by a serialization test).
  Gas: approval step raised to 220 Tgas; claim prepaid ≈ 240 Tgas.
- Relayer: claim cap raised 200 → 300 Tgas for the membership chain; the app must attach 300 Tgas
  on claim delegates (Swift follow-up, not this handoff).
- DAO policy: `apps/api/scripts/dao-policy.json` (genesis values; replace the three placeholder accounts).
  Council holds kind policies for removal only by convention — Sputnik cannot grant VoteRemove without the
  kind policy, so every council vote is possible but unanimous and on-chain visible. Community quorum 3
  is the bootstrap; ratchet to 5% of role size once populated.
- API: `POST /v1/seed`, `ensureSeeded` in the claim path (funder dry → 503, attestation fails closed),
  `seed_log` table (`migrations/0003_seed_log.sql`), 8 new bun tests. Two `near-api-js` byte-compat tests
  fail before and after this change (pre-existing, untouched).

## Deploy checklist

- [ ] Seeder capitalized; module bond float funded (separate line items).
- [ ] Balance alert at 20% seeder runway; seed-vs-claim rate monitor (gap means farming or broken clients).
- [ ] AASA + Auth0 callback already live for `ije.wades.io` (prior handoff).
- [ ] Testnet faucet documented for the permissionless path; mainnet fallback = self-fund.
- [ ] Apply `dao-policy.json` via a ChangePolicy proposal under the current council policy, after
  replacing placeholder accounts and deploying the upgraded treasury + escrow contracts.
- [ ] Upgrade order: treasury (seeder views + auto-join) first, then DAO policy (claims role needs
  AddMemberToRole rights before the first membership proposal lands, else claims still succeed and
  membership retries on the next claim).

## Open questions

- Exact seed amount constant (0.005 suggested: creation + token-storage headroom + lifetime yocto dust).
- Alert channel for seeder/monitor pages.
- Nothing else — thresholds and windows are genesis values the community can ratify later.
