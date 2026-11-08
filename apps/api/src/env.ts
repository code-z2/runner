export interface Env {
  DB: D1Database;
  APP_ID: string;
  APP_ATTEST_ENV: string;
  NEAR_RPC_URL: string;
  NEAR_RECIPIENT: string;
  TREASURY_CONTRACT: string;
  PORTAL_ORIGIN: string;
  MAIL_FROM: string;
  ATTESTOR_SECRET_KEY: string;
  RESEND_API_KEY: string;
}

const REQUIRED: (keyof Omit<Env, "DB">)[] = [
  "APP_ID",
  "APP_ATTEST_ENV",
  "NEAR_RPC_URL",
  "NEAR_RECIPIENT",
  "TREASURY_CONTRACT",
  "PORTAL_ORIGIN",
  "MAIL_FROM",
  "ATTESTOR_SECRET_KEY",
  "RESEND_API_KEY",
];

export function missingSettings(env: Env): string[] {
  const missing: string[] = REQUIRED.filter((name) => !env[name]);
  if (env.APP_ATTEST_ENV && env.APP_ATTEST_ENV !== "production" && env.APP_ATTEST_ENV !== "development") {
    missing.push("APP_ATTEST_ENV");
  }
  return missing;
}

export const nowSeconds = (): number => Math.floor(Date.now() / 1000);
