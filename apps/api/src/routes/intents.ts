import { fromBase64, hashHex, utf8 } from "../codec";
import type { Env } from "../env";
import { HttpError, parseObject } from "../http";
import { oneClick } from "../oneClick";
import { goalQuote } from "./goals";
import { checkDevice } from "./runner";

const ROUTES = new Set(["POST /v0/quote", "GET /v0/tokens", "GET /v0/status"]);

/**
 * Thin 1Click proxy: App Attest, an allowlisted route, the server-side
 * key. Returns the upstream status and body. A payable quote to the escrow
 * is a goal quote and is checked and saved first.
 */
export async function proxyIntent(request: Request, env: Env, url: URL): Promise<Response> {
  const path = url.pathname.slice("/v1/intents".length);
  if (!ROUTES.has(`${request.method} ${path}`)) throw new HttpError(404, "not_found");
  const body = request.method === "POST" ? await request.text() : "";
  if (body.length > 16_384) throw new HttpError(413, "body_too_large");

  const keyId = request.headers.get("x-runner-key-id");
  const assertion = request.headers.get("x-runner-assertion");
  if (!keyId || !assertion) throw new HttpError(401, "missing_assertion");
  await checkDevice(env, keyId, fromBase64(assertion, "invalid_assertion"),
    `${request.method} ${url.pathname}${url.search} ${hashHex(utf8(body))}`);

  if (path === "/v0/quote") {
    const quote = parseObject(body, "invalid_intent_quote");
    if (quote.dry === false && quote.recipient === env.ESCROW_CONTRACT) return goalQuote(env, quote, body);
  }
  const upstream = await oneClick(env.ONE_CLICK_API_KEY, path + url.search,
    body ? { method: "POST", body, headers: { "content-type": "application/json" } } : {});
  return new Response(upstream.body, {
    status: upstream.status,
    headers: { "content-type": upstream.headers.get("content-type") ?? "application/json", "cache-control": "no-store" },
  });
}
