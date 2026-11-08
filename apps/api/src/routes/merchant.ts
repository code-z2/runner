import { hashHex, randomToken, utf8 } from "../codec";
import { nowSeconds, requireSettings, type Env } from "../env";
import { geohash } from "../geohash";
import { HttpError, json, numberField, readJson, stringField, trimmedField, type Json } from "../http";
import { sendSignInLink } from "../mail";
import { isAccountId } from "../near";

const LOGIN_TTL_S = 15 * 60;
const LOGIN_INTERVAL_S = 60;
const SESSION_TTL_S = 30 * 24 * 3600;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CATEGORIES = new Set(["water", "drinks", "snacks", "meals", "goods", "services"]);

export interface Merchant {
  id: string;
  isAdmin: boolean;
}

export interface LocationRow {
  id: string;
  merchant_id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  categories: string;
  near_account: string;
  status: string;
  created_at: number;
  updated_at: number;
}

export const LOCATION_COLUMNS =
  "id, merchant_id, name, address, lat, lng, categories, near_account, status, created_at, updated_at";

export function presentLocation(row: LocationRow): Json {
  return {
    id: row.id,
    name: row.name,
    address: row.address,
    lat: row.lat,
    lng: row.lng,
    categories: JSON.parse(row.categories) as string[],
    near_account: row.near_account,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

const tokenHash = (token: string): string => hashHex(utf8(token));

export async function requestLogin(request: Request, env: Env): Promise<Response> {
  requireSettings(env, ["PORTAL_ORIGIN", "MAIL_FROM", "RESEND_API_KEY"]);
  const body = await readJson(request);
  const email = trimmedField(body, "email", 254).toLowerCase();
  if (!EMAIL.test(email)) {
    throw new HttpError(400, "invalid_email");
  }
  const now = nowSeconds();
  const recent = await env.DB.prepare("SELECT 1 FROM login_tokens WHERE email = ? AND created_at > ? LIMIT 1")
    .bind(email, now - LOGIN_INTERVAL_S)
    .first();
  if (!recent) {
    const token = randomToken();
    await env.DB.prepare("INSERT INTO login_tokens (token_hash, email, expires_at, created_at) VALUES (?, ?, ?, ?)")
      .bind(tokenHash(token), email, now + LOGIN_TTL_S, now)
      .run();
    await sendSignInLink(env, email, token);
  }
  return json({ status: "sent" }, 202);
}

export async function createSession(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const token = stringField(body, "token", 128);
  const now = nowSeconds();
  const login = await env.DB.prepare("DELETE FROM login_tokens WHERE token_hash = ? AND expires_at > ? RETURNING email")
    .bind(tokenHash(token), now)
    .first<{ email: string }>();
  if (!login) {
    throw new HttpError(401, "invalid_token");
  }
  await env.DB.prepare("INSERT OR IGNORE INTO merchants (id, email, is_admin, created_at) VALUES (?, ?, 0, ?)")
    .bind(crypto.randomUUID(), login.email, now)
    .run();
  const merchant = await env.DB.prepare("SELECT id FROM merchants WHERE email = ?")
    .bind(login.email)
    .first<{ id: string }>();
  if (!merchant) {
    throw new HttpError(500, "merchant_missing");
  }
  const session = randomToken();
  await env.DB.prepare("INSERT INTO sessions (token_hash, merchant_id, expires_at) VALUES (?, ?, ?)")
    .bind(tokenHash(session), merchant.id, now + SESSION_TTL_S)
    .run();
  return json({ session, expires_at: now + SESSION_TTL_S }, 201);
}

export async function authenticate(request: Request, env: Env): Promise<Merchant> {
  const header = request.headers.get("authorization") ?? "";
  if (!header.startsWith("Bearer ") || header.length > 7 + 128) {
    throw new HttpError(401, "unauthorized");
  }
  const row = await env.DB.prepare(
    `SELECT m.id, m.is_admin FROM sessions s JOIN merchants m ON m.id = s.merchant_id
     WHERE s.token_hash = ? AND s.expires_at > ?`,
  )
    .bind(tokenHash(header.slice(7)), nowSeconds())
    .first<{ id: string; is_admin: number }>();
  if (!row) {
    throw new HttpError(401, "unauthorized");
  }
  return { id: row.id, isAdmin: row.is_admin === 1 };
}

function categoriesField(body: Json): string[] {
  const value = body.categories;
  if (
    !Array.isArray(value) ||
    value.length > CATEGORIES.size ||
    !value.every((category) => typeof category === "string" && CATEGORIES.has(category)) ||
    new Set(value).size !== value.length ||
    !value.includes("water")
  ) {
    throw new HttpError(400, "invalid_categories");
  }
  return value as string[];
}

function nearAccountField(body: Json): string {
  const value = stringField(body, "near_account", 64);
  if (!isAccountId(value)) {
    throw new HttpError(400, "invalid_near_account");
  }
  return value;
}

export async function listOwnLocations(merchant: Merchant, env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    `SELECT ${LOCATION_COLUMNS} FROM locations WHERE merchant_id = ? ORDER BY created_at`,
  )
    .bind(merchant.id)
    .all<LocationRow>();
  return json({ locations: results.map(presentLocation) });
}

export async function createLocation(request: Request, merchant: Merchant, env: Env): Promise<Response> {
  const body = await readJson(request);
  const lat = numberField(body, "lat", -90, 90);
  const lng = numberField(body, "lng", -180, 180);
  const now = nowSeconds();
  const row = await env.DB.prepare(
    `INSERT INTO locations (id, merchant_id, name, address, lat, lng, geohash5, categories, near_account, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
     RETURNING ${LOCATION_COLUMNS}`,
  )
    .bind(
      crypto.randomUUID(),
      merchant.id,
      trimmedField(body, "name", 120),
      trimmedField(body, "address", 300),
      lat,
      lng,
      geohash(lat, lng),
      JSON.stringify(categoriesField(body)),
      nearAccountField(body),
      now,
      now,
    )
    .first<LocationRow>();
  return json({ location: presentLocation(row!) }, 201);
}

export async function updateLocation(
  request: Request,
  merchant: Merchant,
  env: Env,
  locationId: string,
): Promise<Response> {
  const body = await readJson(request);
  const current = await env.DB.prepare(`SELECT ${LOCATION_COLUMNS} FROM locations WHERE id = ? AND merchant_id = ?`)
    .bind(locationId, merchant.id)
    .first<LocationRow>();
  if (!current) {
    throw new HttpError(404, "location_not_found");
  }
  const lat = "lat" in body ? numberField(body, "lat", -90, 90) : current.lat;
  const lng = "lng" in body ? numberField(body, "lng", -180, 180) : current.lng;
  const nearAccount = "near_account" in body ? nearAccountField(body) : current.near_account;
  const status =
    nearAccount !== current.near_account || current.status === "rejected" ? "pending" : current.status;
  const row = await env.DB.prepare(
    `UPDATE locations SET name = ?, address = ?, lat = ?, lng = ?, geohash5 = ?, categories = ?, near_account = ?, status = ?, updated_at = ?
     WHERE id = ? AND merchant_id = ?
     RETURNING ${LOCATION_COLUMNS}`,
  )
    .bind(
      "name" in body ? trimmedField(body, "name", 120) : current.name,
      "address" in body ? trimmedField(body, "address", 300) : current.address,
      lat,
      lng,
      geohash(lat, lng),
      "categories" in body ? JSON.stringify(categoriesField(body)) : current.categories,
      nearAccount,
      status,
      nowSeconds(),
      locationId,
      merchant.id,
    )
    .first<LocationRow>();
  if (!row) {
    throw new HttpError(404, "location_not_found");
  }
  return json({ location: presentLocation(row) });
}
