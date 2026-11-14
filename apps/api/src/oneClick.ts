import { HttpError } from "./http";

const BASE_URL = "https://1click.chaindefuser.com";

/** Send one request to 1Click with the server-side partner key. */
export async function oneClick(apiKey: string | undefined, path: string, init: RequestInit = {}): Promise<Response> {
  if (!apiKey) throw new HttpError(503, "one_click_unavailable");
  const headers = new Headers(init.headers);
  headers.set("accept", "application/json");
  headers.set("x-api-key", apiKey);
  let response: Response;
  try {
    // Workers support only "follow" and "manual": a redirect must not carry the key elsewhere.
    response = await fetch(BASE_URL + path, { ...init, headers, redirect: "manual", signal: AbortSignal.timeout(15_000) });
  } catch (error) {
    console.error(`1Click ${path.split("?")[0]} failed: ${String(error)}`);
    throw new HttpError(502, "one_click_unavailable");
  }
  if (response.status >= 300 && response.status < 400) throw new HttpError(502, "one_click_redirected");
  return response;
}

/** Parsed JSON body of a successful 1Click call, or an HttpError. */
export async function oneClickJson<T>(apiKey: string | undefined, path: string, init: RequestInit = {}): Promise<T> {
  const response = await oneClick(apiKey, path, init);
  if (!response.ok) throw new HttpError(502, "one_click_rejected");
  return response.json() as Promise<T>;
}
