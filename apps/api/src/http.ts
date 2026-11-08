export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export type Json = Record<string, unknown>;

const MAX_BODY_BYTES = 16384;

export function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return Response.json(body, { status, headers });
}

export async function readJson(request: Request): Promise<Json> {
  if (!(request.headers.get("content-type") ?? "").toLowerCase().startsWith("application/json")) {
    throw new HttpError(415, "json_required");
  }
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) {
    throw new HttpError(413, "body_too_large");
  }
  return parseObject(text, "invalid_json");
}

export function parseObject(text: string, code: string): Json {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new HttpError(400, code);
  }
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpError(400, code);
  }
  return value as Json;
}

export function stringField(body: Json, name: string, maxLength: number): string {
  const value = body[name];
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) {
    throw new HttpError(400, `invalid_${name}`);
  }
  return value;
}

export function trimmedField(body: Json, name: string, maxLength: number): string {
  const value = body[name];
  if (typeof value !== "string") {
    throw new HttpError(400, `invalid_${name}`);
  }
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) {
    throw new HttpError(400, `invalid_${name}`);
  }
  return trimmed;
}

export function integerField(body: Json, name: string, min: number, max: number): number {
  const value = body[name];
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new HttpError(400, `invalid_${name}`);
  }
  return value;
}

export function numberField(body: Json, name: string, min: number, max: number): number {
  const value = body[name];
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpError(400, `invalid_${name}`);
  }
  return value;
}
