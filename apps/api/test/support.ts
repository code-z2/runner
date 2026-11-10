import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { p256 } from "@noble/curves/nist.js";
import { encode } from "cbor-x";
import { concat, hash, utf8 } from "../src/codec";
import type { Env } from "../src/env";

type Value = string | number | null;

class Statement {
  constructor(
    private readonly db: Database,
    private readonly sql: string,
    private readonly params: Value[] = [],
  ) {}

  bind(...params: Value[]): Statement {
    return new Statement(this.db, this.sql, params);
  }

  async first<T>(): Promise<T | null> {
    return (this.db.query(this.sql).get(...this.params) as T | undefined) ?? null;
  }

  async all<T>(): Promise<{ results: T[] }> {
    return { results: this.db.query(this.sql).all(...this.params) as T[] };
  }

  async run(): Promise<{ meta: { changes: number } }> {
    const result = this.db.query(this.sql).run(...this.params);
    return { meta: { changes: result.changes } };
  }
}

export function createDatabase(): D1Database {
  const db = new Database(":memory:");
  for (const file of ["0001_init.sql", "0002_relay_log.sql"]) {
    db.exec(readFileSync(join(import.meta.dir, "..", "migrations", file), "utf8"));
  }
  return {
    prepare: (sql: string) => new Statement(db, sql),
    batch: async (statements: Statement[]) => {
      const results = [];
      db.exec("BEGIN");
      for (const statement of statements) {
        results.push(await statement.run());
      }
      db.exec("COMMIT");
      return results;
    },
  } as unknown as D1Database;
}

export function createEnv(overrides: Partial<Env> = {}): Env {
  return {
    DB: createDatabase(),
    APP_ID: "TEAMID1234.com.runner.app",
    APP_ATTEST_ENV: "development",
    NEAR_RPC_URL: "https://rpc.test.near",
    NEAR_RECIPIENT: "runner-api",
    TREASURY_CONTRACT: "treasury.runner.near",
    ESCROW_CONTRACT: "escrow.runner.near",
    TOKEN_CONTRACT: "usdc.near",
    RELAYER_ACCOUNT_ID: "relayer.runner.near",
    RELAYER_SECRET_KEY: "",
    PORTAL_ORIGIN: "https://portal.runner.test",
    MAIL_FROM: "Runner <login@runner.test>",
    ATTESTOR_SECRET_KEY: Buffer.alloc(32, 7).toString("base64"),
    RESEND_API_KEY: "re_test_key",
    ...overrides,
  };
}

export type FetchHandler = (url: string, init: RequestInit) => Response | Promise<Response>;

export function stubFetch(handler: FetchHandler): () => void {
  const original = globalThis.fetch;
  globalThis.fetch = (async (input: RequestInfo | URL, init: RequestInit = {}) =>
    handler(String(input instanceof Request ? input.url : input), init)) as typeof fetch;
  return () => {
    globalThis.fetch = original;
  };
}

const APP_ID = "TEAMID1234.com.runner.app";

function authenticatorData(counter: number, rpId = APP_ID): Uint8Array {
  const data = new Uint8Array(37);
  data.set(hash(utf8(rpId)), 0);
  data[32] = 0x40;
  new DataView(data.buffer).setUint32(33, counter);
  return data;
}

export function makeAssertion(secret: Uint8Array, clientData: Uint8Array, counter: number, rpId = APP_ID): Uint8Array {
  const authData = authenticatorData(counter, rpId);
  const nonce = hash(concat(authData, hash(clientData)));
  const signature = p256.sign(nonce, secret, { format: "der" });
  return encode({ signature, authenticatorData: authData });
}

