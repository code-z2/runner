import { HttpError } from "./http";

export interface Env {
  DB: D1Database;
  APP_ID: string;
  APP_ATTEST_ENV: string;
  NEAR_RPC_URL: string;
  NEAR_RECIPIENT: string;
  TREASURY_CONTRACT: string;
  ESCROW_CONTRACT: string;
  TOKEN_CONTRACT: string;
  DAO_ACCOUNT: string;
  RELAYER_ACCOUNT_ID: string;
  RELAYER_SECRET_KEY: string;
  PORTAL_ORIGIN: string;
  MAIL_FROM: string;
  ATTESTOR_SECRET_KEY: string;
  RESEND_API_KEY: string;
}

export type Setting = keyof Omit<Env, "DB">;

export function requireSettings(env: Env, names: Setting[]): void {
  const missing = names.filter((name) => !env[name]);
  if (names.includes("APP_ATTEST_ENV") && env.APP_ATTEST_ENV && !["production", "development"].includes(env.APP_ATTEST_ENV)) {
    missing.push("APP_ATTEST_ENV");
  }
  if (missing.length > 0) {
    console.error(`runner-api missing settings: ${missing.join(", ")}`);
    throw new HttpError(503, "misconfigured");
  }
}

export const nowSeconds = (): number => Math.floor(Date.now() / 1000);
