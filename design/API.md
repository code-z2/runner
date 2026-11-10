# API - Runner Backend

Status: AGREED. Peter handed the lead and all open decisions to Joel on 2026-11-08.
Source: `design/ORDER.md` items 4, 7, 8, 9 and 12.

## What the server is for

The app runs fully without the server (F11). The server does three jobs only:

1. Check a finished run and sign a claim pass (attestation) for it.
2. Keep the list of approved merchants and their locations.
3. Let merchants sign up and let admins approve them.

The server never stores routes, runner profiles, run history or encounters.

## Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Faked runs with no daily cap | A run cannot overlap another attested run, and must start at least 4 hours after the last attested run ended. Checked per NEAR account and per device. |
| 2 | Oldest run that can be attested | 6 hours after it ended. |
| 3 | Who sets the amount | Runner types it in after scanning the merchant's fixed QR. |
| 4 | Merchant sign-in | Email link, sent through Resend. |
| 5 | Stack | Cloudflare Workers + D1, TypeScript, bun for install, test and scripts. |

Also decided:

- The signed attestation is the second signature of the 2-of-N (runner + attestor). The server is not called at the merchant. Peter's stub route `/claims/co-sign` is dropped.
- Steps are required for a claim pass. A run without step data still saves on the phone; it just earns no pass.
- Admin approval does not hold a DAO key. The admin passes the Sputnik/Trezu proposal first, then approves in the portal. The server checks the contract before it shows the merchant.
- Amounts are in US cents.

## Runner endpoints

### `POST /v1/challenge`

Returns 32 random bytes, base64. Single use. Expires after 5 minutes.

### `POST /v1/devices`

Registers the phone's App Attest key once per install.

- In: `key_id`, `attestation` (base64), `challenge`.
- Server checks Apple's certificate chain, the nonce, app id, counter and key id.
- Out: `201`. Fails: `400` bad input or challenge, `401` Apple check fails, `409` key already registered.

### `POST /v1/attestations`

Called when the runner opens the claim view after a run.

In:

```json
{
  "payload": "{\"account_id\":\"runner.ije.near\",\"challenge\":\"<base64>\",\"activity\":{...}}",
  "key_id": "<base64>",
  "assertion": "<base64>",
  "near_public_key": "ed25519:<base58>",
  "near_signature": "<base64>"
}
```

`activity` inside the payload:

```json
{
  "id": "device-made uuid",
  "started_at": 1762409400,
  "ended_at": 1762411330,
  "active_seconds": 1830,
  "distance_m": 5120,
  "km_splits_s": [352, 360, 358, 361, 370],
  "steps": 5300
}
```

Times are unix seconds. No GPS points, no heart rate.

Signatures:

- `assertion` is the App Attest assertion with `clientData` = the `payload` bytes.
- `near_signature` is a NEP-413 signed message: `message` = `payload`, `nonce` = the challenge bytes, `recipient` = the server's `NEAR_RECIPIENT`. The key must be a full access key on `account_id`.

Server checks:

- Challenge is unused and not expired.
- App Attest assertion is valid and its counter went up.
- NEAR signature is valid and the key belongs to the account.
- Distance is 2,500 m or more, and `km_splits_s` has one entry per full km.
- Every split and the average pace are between 2:30 and 20:00 per km.
- Step rate is between 100 and 230 per minute.
- Pauses add up to 30 minutes or less.
- The run ended within the last 6 hours and not in the future.
- No overlap with, and at least 4 hours after, the last attested run on the same account or device.

Out `201`:

```json
{
  "attestation": "{\"v\":1,\"account_id\":\"runner.ije.near\",\"activity_hash\":\"<hex>\",\"max_amount_cents\":256,\"expires_at\":1762418530,\"nonce\":\"<hex>\"}",
  "signature": "<base64 ed25519 signature over the attestation bytes>"
}
```

The same response also carries `run_proof` and `run_proof_signature`: the attestor's signature over
`{"v":1,"kind":"run","account_id","activity_hash","started_at","ended_at","distance_m","active_seconds"}`.
The goal escrow uses it to unlock a goal.

- `max_amount_cents` = min(500, floor(distance_m / 20)).
- `expires_at` = now + 2 hours.
- Fails: `400` bad input, `401` signature or device check fails, `409` overlapping or too soon, `422` not eligible with a reason: `too_short`, `bad_splits`, `pace_out_of_range`, `cadence_out_of_range`, `too_many_pauses`, `too_old`, `in_future`.

The app keeps the attestation in the Keychain and hides it once expired.

### `GET /v1/merchants?cells=<geohash5>[,<geohash5>...]`

Lists approved locations in up to 9 coarse cells (about 5 x 5 km each). The app sends its own cell and the 8 around it, never the exact position, and sorts by distance on the phone.

Out: `{ "locations": [ { id, name, lat, lng, categories, near_account } ] }`. Cached by clients for 10 minutes.

## Relayer (`POST /v1/relay`)

Runners never need NEAR for gas. The app signs a NEP-366 `SignedDelegateAction` with the runner's full access key and the server wraps it in a transaction it pays for. The deposit inside the call (the 1 yoctoNEAR some escrow methods need) still comes from the runner's account, so the contracts' full-access check holds.

In:

```json
{
  "signed_delegate": "<base64 borsh SignedDelegateAction>",
  "key_id": "<base64>",
  "assertion": "<base64 App Attest assertion, clientData = the signed_delegate string>"
}
```

Server checks, in order:

- Exactly one `FunctionCall` action, on the allow-list below, with exactly the listed deposit and no more than the listed gas.
- The delegate signature is valid for its public key, and that key is a full access key on `sender_id`.
- The delegate nonce is above the key's current nonce, and `max_block_height` is ahead of the chain but no more than 1,000 blocks.
- App Attest assertion from a registered device.
- At most 30 relays an hour per account and per device.

Allow-list:

| Contract | Method | Deposit | Max gas |
|---|---|---|---|
| `TREASURY_CONTRACT` (claims module) | `claim` | 0 | 200 Tgas |
| `ESCROW_CONTRACT` | `unlock`, `flush_pool` | 0 | 100 Tgas |
| `ESCROW_CONTRACT` | `give_up`, `withdraw`, `lock_from_balance` | 1 yoctoNEAR | 100 Tgas |
| `TOKEN_CONTRACT` | `ft_transfer_call` with `receiver_id` = escrow | 1 yoctoNEAR | 100 Tgas |
| `TOKEN_CONTRACT` | `ft_transfer` with `receiver_id` = `DAO_ACCOUNT` (donation) | 1 yoctoNEAR | 30 Tgas |

Out `200`: `{ "transaction_hash": "<base58>", "status": "succeeded" | "failed", "failure"?: <NEAR failure> }`. A `failed` status means the transaction ran and the contract refused it.

Fails: `400` bad input, `401` signature, key or device check fails, `409` delegate nonce already used, `422` call not allowed, `429` too many relays, `502` NEAR rejected the transaction, `503` relayer not configured or busy.

## Claim at the merchant (contract, no server call)

1. Merchant shows a fixed QR with their `near_account`.
2. Runner scans it and types the amount the merchant tells them.
3. App sends one transaction to the treasury contract with the attestation, its signature, the merchant and the amount.
4. Contract checks: attestor signature, not expired, nonce unused, merchant registered, amount up to `max_amount_cents`. Then pays and marks the nonce used.

A smaller spend still uses up the whole pass (item 8).

## Merchant portal endpoints

Session token goes in `Authorization: Bearer <token>`.

- `POST /v1/merchant/login` - `{ email }`. Always `202`. Sends a sign-in link, at most one a minute per email.
- `POST /v1/merchant/session` - `{ token }` from the link. Returns `{ session }`, valid 30 days.
- `GET /v1/merchant/locations` - own locations and status.
- `POST /v1/merchant/locations` - name, address, `lat`, `lng`, categories, `near_account`. Starts as `pending`.
- `PATCH /v1/merchant/locations/:id` - edit details. Changing `near_account` sends it back to `pending`.

Categories: `water` (required), `drinks`, `snacks`, `meals`, `goods`, `services`.

## Admin endpoints

Same sign-in. The admin flag is set by hand in the database.

- `GET /v1/admin/locations?status=pending`
- `POST /v1/admin/locations/:id/approve` - `409 not_registered_onchain` until `is_merchant` on the treasury contract returns true for the location's `near_account`.
- `POST /v1/admin/locations/:id/reject`

## What the server stores

| Table | Fields | Kept for |
|---|---|---|
| challenges | id, expires_at | 5 minutes |
| devices | key_id, public_key, counter, created_at | while in use |
| attested_activities | activity_hash, account_id, key_id, started_at, ended_at, created_at | 3 days after the run ended |
| merchants | id, email, is_admin, created_at | while in use |
| login_tokens | token_hash, email, expires_at, created_at | 15 minutes |
| sessions | token_hash, merchant_id, expires_at | 30 days |
| locations | id, merchant_id, name, address, lat, lng, geohash5, categories, near_account, status, created_at, updated_at | while in use |

An hourly job deletes rows past their time.

## Settings

| Name | Kind | Meaning |
|---|---|---|
| `APP_ID` | var | `<TEAMID>.<bundle id>` for App Attest |
| `APP_ATTEST_ENV` | var | `production` or `development` |
| `NEAR_RPC_URL` | var | NEAR RPC endpoint |
| `NEAR_RECIPIENT` | var | NEP-413 recipient the app signs for |
| `TREASURY_CONTRACT` | var | Treasury account id, for `is_merchant` |
| `PORTAL_ORIGIN` | var | Merchant portal origin, for CORS and sign-in links |
| `MAIL_FROM` | var | Sender address for sign-in links |
| `ATTESTOR_SECRET_KEY` | secret | Ed25519 seed, 32 bytes, base64 |
| `RESEND_API_KEY` | secret | Resend key |
| `ESCROW_CONTRACT` | var | Goal escrow account id, for the relayer allow-list |
| `TOKEN_CONTRACT` | var | Stablecoin account id the pool and escrow hold |
| `DAO_ACCOUNT` | var | Sputnik DAO that holds the pool, for donations through the relayer |
| `RELAYER_ACCOUNT_ID` | var | NEAR account that pays relay gas |
| `RELAYER_SECRET_KEY` | secret | That account's full access key, `ed25519:<base58 64 bytes>` |

## Community treasury: Sputnik DAO + claims module

The pool's money lives in a Sputnik DAO v2 (ORDER item 8: "Treasury on Sputnik/Trezu"), managed through Trezu. `contracts/treasury` is the claims module: it holds no money, keeps the rules, and is the only member of a DAO role that may approve payouts.

### The DAO

Created from the Sputnik factory (`sputnik-v2.testnet` on testnet, `sputnik-dao.near` on mainnet). Policy:

```json
{
  "roles": [
    {
      "name": "council",
      "kind": { "Group": ["<joel>", "<peter>"] },
      "permissions": ["*:*"],
      "vote_policy": {}
    },
    {
      "name": "claims",
      "kind": { "Group": ["<claims module account>"] },
      "permissions": ["transfer:AddProposal", "transfer:VoteApprove"],
      "vote_policy": { "transfer": { "weight_kind": "RoleWeight", "quorum": "0", "threshold": [1, 1] } }
    }
  ],
  "default_vote_policy": { "weight_kind": "RoleWeight", "quorum": "0", "threshold": [1, 2] },
  "proposal_bond": "100000000000000000000000",
  "proposal_period": "604800000000000",
  "bounty_bond": "100000000000000000000000",
  "bounty_forgiveness_period": "86400000000000"
}
```

- Sputnik approves a proposal as soon as any one role reaches its threshold. The claims role has one member and a 1-of-1 threshold for `transfer`, so the module approves payouts alone and runners claim without waiting for votes.
- The claims role can do nothing else: it cannot add or approve any other proposal kind.
- Everything else needs the council: with two members and `[1, 2]`, both must approve. That covers policy, merchants, the attestor, pausing and any other movement of funds.
- The DAO must be registered with the stablecoin contract (`storage_deposit`) to hold it.

### Claims module (`contracts/treasury`)

Setup: `new(dao_id, token_id, attestor_public_key, units_per_cent, proposal_bond)`. For USDC (6 decimals), `units_per_cent` is `10000`. `proposal_bond` must equal the DAO's `proposal_bond`.

Runner call: `claim(attestation, signature, merchant_id, amount_cents)`, about 150 Tgas, sent by the runner's own account (directly or through the relayer).

1. Checks the attestor signature, version, caller, expiry, registered merchant, amount, and single use, then marks the pass used.
2. Adds a DAO `Transfer` proposal (token, merchant, amount), attaching the bond from the module's own NEAR balance.
3. Votes to approve it as the claims role. The DAO pays the merchant and returns the bond.

If the DAO refuses the proposal in step 2, the pass is freed for a retry. If step 3 fails, the proposal stays open for the council and the pass stays used, so it can never be paid twice. If the DAO's token transfer itself fails (for example the merchant is not registered with the token), Sputnik marks the proposal Failed and anyone can re-run it with `act_proposal(id, "Finalize")` once fixed.

DAO calls (through council `FunctionCall` proposals): `add_merchant`, `remove_merchant`, `set_attestor`, `set_proposal_bond`, `set_dao`, `pause`, `unpause`.

One attestor for the whole system: the module holds the only copy of the attestor key and exposes it with `get_attestor()`. The goal escrow reads it from there on every unlock, so one council vote changes the key for both contracts.

Views: `is_merchant(account_id)`, `is_nonce_used(nonce)`, `get_attestor()`, `get_config()`.

Donations go straight to the DAO account as a plain `ft_transfer` of the stablecoin.

### Deploy order

1. Create the claims module account and the DAO with the policy above.
2. Register the DAO and each merchant with the stablecoin (`storage_deposit`).
3. Deploy the claims module with `new(dao_id, ...)`, and fund it with a few NEAR for bonds and storage.
4. Deploy the goal escrow with `treasury_id` = the claims module and `pool_id` = the DAO.
5. Council adds merchants through `FunctionCall` proposals to `add_merchant`.

## Goal escrow contract (`contracts/escrow`)

NEAR contract, near-sdk 5.30.1, same build image as the treasury. Holds runners' own money locked on goals. No private balance anywhere else (ORDER item 13).

Setup: `new(owner_id, token_id, treasury_id, pool_id, min_lock)`. `treasury_id` is the claims module (for the attestor); `pool_id` is the DAO that receives the pool's half when a runner gives up.

- Lock: send the token with `ft_transfer_call` and `msg` = `{"distance_m":10000,"max_seconds":3300}` (`max_seconds` optional). Below `min_lock`, a bad goal or another token is refunded.
- Goals: 1,000 to 100,000 m, and 60 s to 24 h when timed.
- `unlock(lock_id, proof, signature)`: by the lock owner, with a run proof from the server. The run must start after the lock was made, cover the distance, and beat the time at its average pace. The escrow then reads the attestor key from `treasury.get_attestor()` and checks the signature in a second step; if the treasury cannot answer, the unlock fails and nothing changes. The money moves to the owner's unlocked balance in the escrow. Attach about 30 Tgas.
- `give_up(lock_id)`: half to the owner's unlocked balance, half sent to the DAO pool (`pool_id`). A failed pool transfer is kept as `pool_owed`; anyone can retry with `flush_pool()`.
- `withdraw(amount, receiver_id?)`: moves unlocked money out. Restored if the transfer fails.
- `lock_from_balance(amount, goal)`: lock unlocked money again.
- `withdraw`, `give_up` and `lock_from_balance` need 1 yoctoNEAR attached, so only a full access key can move money.
- Owner (DAO): `set_min_lock`, `set_owner`. No pause and no admin withdraw: runners can always take their unlocked money out.
- Attestor: the escrow stores no key of its own; it always uses the treasury's. Escrow funds still stay in this contract, apart from the pool.
- Views: `get_lock`, `get_locks(account_id)`, `get_balance(account_id)`, `get_config()`.
- No deadline and no automatic loss (item 10).
