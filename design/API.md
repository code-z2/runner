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
  "payload": "{\"account_id\":\"runner.near\",\"challenge\":\"<base64>\",\"activity\":{...}}",
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
  "attestation": "{\"v\":1,\"account_id\":\"runner.near\",\"activity_hash\":\"<hex>\",\"max_amount_cents\":256,\"expires_at\":1762418530,\"nonce\":\"<hex>\"}",
  "signature": "<base64 ed25519 signature over the attestation bytes>"
}
```

- `max_amount_cents` = min(500, floor(distance_m / 20)).
- `expires_at` = now + 2 hours.
- Fails: `400` bad input, `401` signature or device check fails, `409` overlapping or too soon, `422` not eligible with a reason: `too_short`, `bad_splits`, `pace_out_of_range`, `cadence_out_of_range`, `too_many_pauses`, `too_old`, `in_future`.

The app keeps the attestation in the Keychain and hides it once expired.

### `GET /v1/merchants?cells=<geohash5>[,<geohash5>...]`

Lists approved locations in up to 9 coarse cells (about 5 x 5 km each). The app sends its own cell and the 8 around it, never the exact position, and sorts by distance on the phone.

Out: `{ "locations": [ { id, name, lat, lng, categories, near_account } ] }`. Cached by clients for 10 minutes.

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
