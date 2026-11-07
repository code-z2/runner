# API Proposal - Runner Backend

Status: DRAFT for discussion. Nothing here is agreed until it moves into `design/ORDER.md`.
Source: `design/ORDER.md` items 4, 7, 8, 9.

## What the server is for

The app runs fully without the server (F11). The server does three jobs only:

1. Check a finished run and sign a claim pass (attestation) for it.
2. Keep the list of approved merchants and their locations.
3. Let merchants sign up and let admins approve them.

The server never stores routes, runner profiles, run history or encounters.

## Assumptions

- Stack: Cloudflare Workers + D1, written in TypeScript with bun. Picked because `.gitignore` already lists `.wrangler/`, `.dev.vars` and `*.db`.
- The signed attestation is the second signature of the 2-of-N (runner + attestor). The contract checks it at claim time. The server is not called at the merchant.
- Runners have no server account. A runner is known only by their NEAR account, and only once they open the wallet.
- All routes are under `/v1`. JSON in and out.

## Runner endpoints

### `GET /v1/challenge`

Returns a one-time random value used by Apple App Attest. Expires after 5 minutes.

### `POST /v1/devices`

Registers the phone's App Attest key once per install.

- In: `key_id`, `attestation`, `challenge`.
- Out: `201`. Server keeps `key_id`, public key and sign counter.
- Fails: `400` bad or reused challenge, `401` Apple check fails.

### `POST /v1/attestations`

Called when the runner opens the claim view after a run. Not called by the run itself (item 4).

In:

```json
{
  "account_id": "runner.near",
  "activity": {
    "id": "device-made uuid",
    "started_at": "2026-11-06T06:10:00Z",
    "ended_at": "2026-11-06T06:42:10Z",
    "active_seconds": 1830,
    "distance_m": 5120,
    "km_splits_s": [352, 360, 358, 361, 370],
    "steps": 5300
  },
  "assertion": "App Attest assertion over the body",
  "account_signature": "NEAR key signature over the body"
}
```

No GPS points, no heart rate.

Server checks:

- App Attest assertion is valid for a known device.
- `account_signature` matches a key on `account_id`.
- Distance is 2.5 km or more.
- Pace and step rate are in a human range for every split.
- The run ended within the last N hours (see open questions).
- This activity was not attested before.
- It does not overlap in time with another attested run on the same account.

Out `201`:

```json
{
  "attestation": {
    "account_id": "runner.near",
    "activity_hash": "sha256 of activity",
    "max_amount_usd": "2.56",
    "expires_at": "2026-11-06T08:45:00Z",
    "nonce": "random 32 bytes"
  },
  "signature": "attestor signature"
}
```

- `max_amount_usd` = min(5.00, 0.50 x km).
- `expires_at` = now + 2 hours.
- Fails: `401` device or account check fails, `409` already attested or overlapping, `422` not eligible with a plain reason (`too_short`, `pace_out_of_range`, `too_old`).

The app keeps the attestation in the Keychain and hides it once expired.

### `GET /v1/merchants?cell=<geohash5>`

Lists approved locations in a coarse area (about 5 x 5 km). The app sends the cell, never the exact position, and sorts by distance on the phone.

Out: list of `id`, `name`, `lat`, `lng`, `categories`, `near_account`. Cached at the edge for 10 minutes. No offers or stock (item 7).

## Claim at the merchant (contract, no server call)

1. Merchant shows a fixed QR with their `near_account`.
2. Runner scans it, enters the amount the merchant tells them.
3. App sends one transaction to the treasury contract with the attestation, its signature, the merchant and the amount.
4. Contract checks: attestor signature, not expired, nonce unused, merchant registered, amount up to `max_amount_usd`. Then pays and marks the nonce used.

A smaller spend still uses up the whole pass (item 8).

## Merchant portal endpoints

- `POST /v1/merchant/session` - sign in by email link.
- `POST /v1/merchant/locations` - name, address, `lat`, `lng`, categories (water required), `near_account`. Starts as `pending`.
- `GET /v1/merchant/locations` - own locations and status.
- `PATCH /v1/merchant/locations/:id` - edit details. Changing `near_account` sends it back to `pending`.

## Admin endpoints

- `GET /v1/admin/locations?status=pending`
- `POST /v1/admin/locations/:id/approve` - marks approved and opens a Sputnik proposal to add `near_account` to the onchain registry. Shows in discovery once the proposal passes.
- `POST /v1/admin/locations/:id/reject`

Admins sign in with the same email link, plus an admin flag set by hand.

## What the server stores

| Table | Fields |
|---|---|
| devices | key_id, public_key, counter, created_at |
| attested_activities | activity_hash, account_id, started_at, ended_at, created_at |
| merchants | id, email, created_at |
| locations | id, merchant_id, name, address, lat, lng, geohash5, categories, near_account, status |

`attested_activities` is kept only as long as needed to block repeats and overlaps.

## Open questions for Peter

1. No daily caps (item 8) means a faked run can claim $5 about every 30 minutes. The overlap check above helps but does not stop it. Do we accept that for the demo, or add a minimum gap between attestations per account?
2. How old can a run be when it is attested? Proposal: 6 hours.
3. Who sets the amount: the runner typing it in (above), or a per-sale QR from the merchant portal?
4. Merchant sign-in: email link fine, or something else?
5. Is Workers + D1 the stack you had in mind?
