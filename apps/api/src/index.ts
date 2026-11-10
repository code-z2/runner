import { nowSeconds, type Env } from "./env";
import { HttpError, json } from "./http";
import { listLocations, reviewLocation } from "./routes/admin";
import {
  authenticate,
  createLocation,
  createSession,
  listOwnLocations,
  requestLogin,
  updateLocation,
} from "./routes/merchant";
import { relay } from "./routes/relay";
import { createAttestation, createChallenge, listMerchants, registerDevice } from "./routes/runner";
import { seedAccount } from "./routes/seed";

const ATTESTED_RETENTION_S = 3 * 24 * 3600;
const LOCATION_PATH = /^\/v1\/merchant\/locations\/([0-9a-f-]{36})$/;
const REVIEW_PATH = /^\/v1\/admin\/locations\/([0-9a-f-]{36})\/(approve|reject)$/;

function corsHeaders(env: Env): Record<string, string> {
  return {
    "access-control-allow-origin": env.PORTAL_ORIGIN,
    "access-control-allow-methods": "GET, POST, PATCH, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-max-age": "86400",
    vary: "origin",
  };
}

async function route(request: Request, env: Env, url: URL): Promise<Response> {
  const { pathname } = url;
  const method = request.method;

  if (method === "POST" && pathname === "/v1/challenge") return createChallenge(env);
  if (method === "POST" && pathname === "/v1/devices") return registerDevice(request, env);
  if (method === "POST" && pathname === "/v1/attestations") return createAttestation(request, env);
  if (method === "GET" && pathname === "/v1/merchants") return listMerchants(url, env);
  if (method === "POST" && pathname === "/v1/relay") return relay(request, env);
  if (method === "POST" && pathname === "/v1/seed") return seedAccount(request, env);

  if (method === "POST" && pathname === "/v1/merchant/login") return requestLogin(request, env);
  if (method === "POST" && pathname === "/v1/merchant/session") return createSession(request, env);
  if (pathname === "/v1/merchant/locations") {
    if (method === "GET") return listOwnLocations(await authenticate(request, env), env);
    if (method === "POST") return createLocation(request, await authenticate(request, env), env);
  }
  const locationMatch = LOCATION_PATH.exec(pathname);
  if (locationMatch && method === "PATCH") {
    return updateLocation(request, await authenticate(request, env), env, locationMatch[1]);
  }

  if (method === "GET" && pathname === "/v1/admin/locations") {
    return listLocations(url, await authenticate(request, env), env);
  }
  const reviewMatch = REVIEW_PATH.exec(pathname);
  if (reviewMatch && method === "POST") {
    const decision = reviewMatch[2] === "approve" ? "approved" : "rejected";
    return reviewLocation(await authenticate(request, env), env, reviewMatch[1], decision);
  }

  throw new HttpError(404, "not_found");
}

export async function handle(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const portalRoute = url.pathname.startsWith("/v1/merchant/") || url.pathname.startsWith("/v1/admin/");
  const extraHeaders = portalRoute && env.PORTAL_ORIGIN ? corsHeaders(env) : {};

  if (portalRoute && request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: extraHeaders });
  }

  let response: Response;
  try {
    response = await route(request, env, url);
  } catch (error) {
    if (error instanceof HttpError) {
      response = json({ error: error.code }, error.status);
    } else {
      console.error(error);
      response = json({ error: "internal" }, 500);
    }
  }
  for (const [name, value] of Object.entries(extraHeaders)) {
    response.headers.set(name, value);
  }
  return response;
}

export async function cleanup(env: Env): Promise<void> {
  const now = nowSeconds();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM challenges WHERE expires_at <= ?").bind(now),
    env.DB.prepare("DELETE FROM login_tokens WHERE expires_at <= ?").bind(now),
    env.DB.prepare("DELETE FROM sessions WHERE expires_at <= ?").bind(now),
    env.DB.prepare("DELETE FROM attested_activities WHERE ended_at < ?").bind(now - ATTESTED_RETENTION_S),
    env.DB.prepare("DELETE FROM relay_log WHERE created_at < ?").bind(now - 3600),
  ]);
}

export default {
  fetch: handle,
  async scheduled(_controller: ScheduledController, env: Env, context: ExecutionContext): Promise<void> {
    context.waitUntil(cleanup(env));
  },
} satisfies ExportedHandler<Env>;
