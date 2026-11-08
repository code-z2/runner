import type { Env } from "./env";
import { HttpError } from "./http";

export async function sendSignInLink(env: Env, email: string, token: string): Promise<void> {
  const link = `${env.PORTAL_ORIGIN}/login#token=${token}`;
  let response: Response;
  try {
    response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
      body: JSON.stringify({
        from: env.MAIL_FROM,
        to: [email],
        subject: "Your Runner sign-in link",
        text: `Sign in to the Runner merchant portal:\n\n${link}\n\nThis link works once and expires in 15 minutes. If you did not ask for it, ignore this email.`,
      }),
    });
  } catch {
    throw new HttpError(502, "mail_unavailable");
  }
  if (!response.ok) {
    throw new HttpError(502, "mail_unavailable");
  }
}
