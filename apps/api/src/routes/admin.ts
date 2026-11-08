import { nowSeconds, requireSettings, type Env } from "../env";
import { HttpError, json } from "../http";
import { isRegisteredMerchant } from "../near";
import { LOCATION_COLUMNS, presentLocation, type LocationRow, type Merchant } from "./merchant";

const STATUSES = new Set(["pending", "approved", "rejected"]);

function requireAdmin(merchant: Merchant): void {
  if (!merchant.isAdmin) {
    throw new HttpError(403, "forbidden");
  }
}

export async function listLocations(url: URL, merchant: Merchant, env: Env): Promise<Response> {
  requireAdmin(merchant);
  const status = url.searchParams.get("status") ?? "pending";
  if (!STATUSES.has(status)) {
    throw new HttpError(400, "invalid_status");
  }
  const { results } = await env.DB.prepare(
    `SELECT ${LOCATION_COLUMNS} FROM locations WHERE status = ? ORDER BY created_at LIMIT 500`,
  )
    .bind(status)
    .all<LocationRow>();
  return json({ locations: results.map(presentLocation) });
}

export async function reviewLocation(
  merchant: Merchant,
  env: Env,
  locationId: string,
  decision: "approved" | "rejected",
): Promise<Response> {
  requireAdmin(merchant);
  const location = await env.DB.prepare(`SELECT ${LOCATION_COLUMNS} FROM locations WHERE id = ?`)
    .bind(locationId)
    .first<LocationRow>();
  if (!location) {
    throw new HttpError(404, "location_not_found");
  }
  if (decision === "approved") {
    requireSettings(env, ["NEAR_RPC_URL", "TREASURY_CONTRACT"]);
  }
  if (
    decision === "approved" &&
    !(await isRegisteredMerchant(env.NEAR_RPC_URL, env.TREASURY_CONTRACT, location.near_account))
  ) {
    throw new HttpError(409, "not_registered_onchain");
  }
  const row = await env.DB.prepare(
    `UPDATE locations SET status = ?, updated_at = ? WHERE id = ? AND near_account = ? RETURNING ${LOCATION_COLUMNS}`,
  )
    .bind(decision, nowSeconds(), locationId, location.near_account)
    .first<LocationRow>();
  if (!row) {
    throw new HttpError(409, "location_changed");
  }
  return json({ location: presentLocation(row) });
}
