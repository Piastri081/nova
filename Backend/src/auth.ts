import type { Env, LoginCodeRow, ProfileRow, UserRow } from "./types";
import { publicProfile, publicUser } from "./types";
import {
  HttpError,
  json,
  randomCode,
  randomHex,
  readJson,
  requirePepper,
  sha256
} from "./http";

type Channel = "email" | "sms";

interface NormalizedIdentifier {
  channel: Channel;
  value: string;
}

interface IdentifierBody {
  identifier?: unknown;
}

interface VerifyBody {
  identifier?: unknown;
  code?: unknown;
}

const CODE_TTL_MS = 10 * 60 * 1000;
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const RATE_WINDOW_MS = 15 * 60 * 1000;
const DAILY_WINDOW_MS = 24 * 60 * 60 * 1000;
const DEFAULT_AVATAR = "#E50914";

function normalizeIdentifier(raw: unknown): NormalizedIdentifier {
  if (typeof raw !== "string") {
    throw new HttpError(400, "Enter an email address or phone number.");
  }

  const input = raw.trim();
  if (!input) {
    throw new HttpError(400, "Enter an email address or phone number.");
  }

  if (input.includes("@")) {
    const value = input.toLowerCase();
    if (
      value.length > 254 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)
    ) {
      throw new HttpError(400, "That email address doesn't look valid.");
    }
    return { channel: "email", value };
  }

  let value = input.replace(/[\s().-]/g, "");
  if (value.startsWith("00")) {
    value = `+${value.slice(2)}`;
  }
  if (/^\d{10}$/.test(value)) {
    value = `+1${value}`;
  }
  if (/^1\d{10}$/.test(value)) {
    value = `+${value}`;
  }
  if (!/^\+[1-9]\d{7,14}$/.test(value)) {
    throw new HttpError(400, "Use an international phone number, for example +15551234567.");
  }

  return { channel: "sms", value };
}

function defaultName(identifier: NormalizedIdentifier): string {
  if (identifier.channel === "sms") {
    return "Nova Member";
  }

  const local = identifier.value.split("@")[0].replace(/[._-]+/g, " ").trim();
  if (!local) {
    return "Nova Member";
  }

  const name = local
    .split(/\s+/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ")
    .slice(0, 40);

  return name || "Nova Member";
}

async function countRecentCodes(
  env: Env,
  column: "identifier" | "ip",
  value: string,
  since: number
): Promise<number> {
  const row = await env.DB.prepare(
    `SELECT COUNT(*) AS count FROM login_codes WHERE ${column} = ? AND created_at > ?`
  )
    .bind(value, since)
    .first<{ count: number }>();

  return row?.count ?? 0;
}

function emailContent(code: string) {
  const html = `
  <div style="background:#0a0a0c;padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#fff">
    <div style="max-width:480px;margin:0 auto;background:#141418;border-radius:16px;padding:28px">
      <div style="font-size:26px;font-weight:900;letter-spacing:2px;margin-bottom:8px">
        <span style="color:#e50914">N</span>OVA
      </div>
      <p style="color:#b3b3b3;font-size:14px;line-height:1.6;margin:0 0 24px">
        Use this code to sign in. It expires in 10 minutes.
      </p>
      <div style="font-size:38px;font-weight:800;letter-spacing:12px;background:#0a0a0c;border-radius:12px;padding:18px 24px;text-align:center">
        ${code}
      </div>
      <p style="color:#777;font-size:12px;line-height:1.6;margin:24px 0 0">
        If you didn't request this code, you can safely ignore this email.
        Nova never asks for your password or payment details.
      </p>
    </div>
  </div>`;

  return {
    subject: `${code} is your Nova code`,
    text: `Your Nova code is ${code}. It expires in 10 minutes. If you didn't request it, ignore this email.`,
    html
  };
}

async function sendEmailResend(env: Env, to: string, code: string): Promise<void> {
  const { subject, text, html } = emailContent(code);

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.RESEND_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      from: env.EMAIL_FROM,
      to: [to],
      subject,
      text,
      html
    })
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error("Resend delivery failed", response.status, detail);
    throw new Error("Email delivery failed");
  }
}

async function sendEmailBrevo(env: Env, to: string, code: string): Promise<void> {
  const { subject, text, html } = emailContent(code);

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": env.BREVO_API_KEY as string,
      "content-type": "application/json",
      accept: "application/json"
    },
    body: JSON.stringify({
      sender: { name: "Nova", email: env.EMAIL_FROM },
      to: [{ email: to }],
      subject,
      textContent: text,
      htmlContent: html
    })
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error("Brevo delivery failed", response.status, detail);
    throw new Error("Email delivery failed");
  }
}

async function sendEmail(env: Env, to: string, code: string): Promise<void> {
  if (env.BREVO_API_KEY) {
    return sendEmailBrevo(env, to, code);
  }
  return sendEmailResend(env, to, code);
}

async function sendSms(env: Env, to: string, code: string): Promise<void> {
  const accountSid = env.TWILIO_ACCOUNT_SID as string;
  const token = env.TWILIO_AUTH_TOKEN as string;
  const body = new URLSearchParams({
    To: to,
    From: env.TWILIO_FROM as string,
    Body: `Nova: ${code} is your sign-in code. It expires in 10 minutes.`
  });

  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
    {
      method: "POST",
      headers: {
        authorization: `Basic ${btoa(`${accountSid}:${token}`)}`,
        "content-type": "application/x-www-form-urlencoded"
      },
      body
    }
  );

  if (!response.ok) {
    const detail = await response.text();
    console.error("Twilio delivery failed", response.status, detail);
    throw new Error("SMS delivery failed");
  }
}

export async function requireUser(request: Request, env: Env): Promise<UserRow> {
  const header = request.headers.get("authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";

  if (!token) {
    throw new HttpError(401, "Sign in to continue.");
  }

  const tokenHash = await sha256(token);
  const user = await env.DB.prepare(
    `SELECT u.* FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token_hash = ? AND s.expires_at > ?`
  )
    .bind(tokenHash, Date.now())
    .first<UserRow>();

  if (!user) {
    throw new HttpError(401, "Your session expired. Sign in again.");
  }

  return user;
}

async function requestCode(request: Request, env: Env): Promise<Response> {
  const pepper = requirePepper(env);
  const body = await readJson<IdentifierBody>(request);
  const identifier = normalizeIdentifier(body.identifier);
  const now = Date.now();
  const since = now - RATE_WINDOW_MS;
  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";

  if ((await countRecentCodes(env, "identifier", identifier.value, since)) >= 5) {
    throw new HttpError(429, "Too many codes requested. Try again in 15 minutes.");
  }

  if ((await countRecentCodes(env, "ip", ip, since)) >= 25) {
    throw new HttpError(429, "Too many requests from this network. Try again later.");
  }

  if (
    (await countRecentCodes(env, "identifier", identifier.value, now - DAILY_WINDOW_MS)) >= 20
  ) {
    throw new HttpError(429, "This address has requested too many codes today.");
  }

  if ((await countRecentCodes(env, "ip", ip, now - DAILY_WINDOW_MS)) >= 100) {
    throw new HttpError(429, "Too many requests from this network today.");
  }

  const code = randomCode();
  const codeHash = await sha256(`${pepper}:${identifier.value}:${code}`);
  const id = `code_${randomHex(12)}`;
  const expiresAt = now + CODE_TTL_MS;

  await env.DB.prepare(
    `INSERT INTO login_codes
       (id, identifier, channel, code_hash, expires_at, attempts, created_at, ip)
     VALUES (?, ?, ?, ?, ?, 0, ?, ?)`
  )
    .bind(id, identifier.value, identifier.channel, codeHash, expiresAt, now, ip)
    .run();

  const devMode = env.DEV_RETURN_CODE === "true";
  const configured =
    identifier.channel === "email"
      ? Boolean(env.EMAIL_FROM && (env.RESEND_API_KEY || env.BREVO_API_KEY))
      : Boolean(
          env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_FROM
        );

  if (!devMode) {
    if (!configured) {
      await env.DB.prepare("DELETE FROM login_codes WHERE id = ?").bind(id).run();
      console.error("Login delivery is not configured", identifier.channel);
      throw new HttpError(
        503,
        "Sign-in codes are temporarily unavailable. Please try again later."
      );
    }

    try {
      if (identifier.channel === "email") {
        await sendEmail(env, identifier.value, code);
      } else {
        await sendSms(env, identifier.value, code);
      }
    } catch {
      await env.DB.prepare("DELETE FROM login_codes WHERE id = ?").bind(id).run();
      throw new HttpError(502, "Could not send the code. Try again in a moment.");
    }
  }

  return json({
    ok: true,
    channel: identifier.channel,
    expiresIn: Math.floor(CODE_TTL_MS / 1000),
    ...(devMode ? { devCode: code } : {})
  });
}

async function verifyCode(request: Request, env: Env): Promise<Response> {
  const pepper = requirePepper(env);
  const body = await readJson<VerifyBody>(request);
  const identifier = normalizeIdentifier(body.identifier);
  const code = typeof body.code === "string" ? body.code.trim() : "";

  if (!/^\d{6}$/.test(code)) {
    throw new HttpError(400, "Enter the 6-digit code.");
  }

  const record = await env.DB.prepare(
    `SELECT * FROM login_codes
     WHERE identifier = ? AND consumed_at IS NULL
     ORDER BY created_at DESC
     LIMIT 1`
  )
    .bind(identifier.value)
    .first<LoginCodeRow>();

  if (!record) {
    throw new HttpError(400, "Request a new code first.");
  }

  if (record.expires_at < Date.now()) {
    throw new HttpError(400, "That code expired. Request a new one.");
  }

  if (record.attempts >= 5) {
    throw new HttpError(429, "Too many attempts. Request a new code.");
  }

  const candidateHash = await sha256(`${pepper}:${identifier.value}:${code}`);
  if (candidateHash !== record.code_hash) {
    await env.DB.prepare(
      "UPDATE login_codes SET attempts = attempts + 1 WHERE id = ?"
    )
      .bind(record.id)
      .run();
    throw new HttpError(400, "That code is incorrect.");
  }

  const now = Date.now();
  await env.DB.prepare(
    "UPDATE login_codes SET consumed_at = ? WHERE id = ?"
  )
    .bind(now, record.id)
    .run();

  let user = await env.DB.prepare("SELECT * FROM users WHERE identifier = ?")
    .bind(identifier.value)
    .first<UserRow>();
  let isNewUser = false;

  if (!user) {
    isNewUser = true;
    const userId = `usr_${randomHex(10)}`;
    const name = defaultName(identifier);

    try {
      await env.DB.prepare(
        `INSERT INTO users (id, identifier, email, phone, name, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      )
        .bind(
          userId,
          identifier.value,
          identifier.channel === "email" ? identifier.value : null,
          identifier.channel === "sms" ? identifier.value : null,
          name,
          now
        )
        .run();
    } catch (error) {
      console.error("User insert raced", error);
    }

    user = await env.DB.prepare("SELECT * FROM users WHERE identifier = ?")
      .bind(identifier.value)
      .first<UserRow>();
  }

  if (!user) {
    throw new HttpError(500, "Could not create your account.");
  }

  let profileResult = await env.DB.prepare(
    "SELECT * FROM profiles WHERE user_id = ? ORDER BY created_at ASC"
  )
    .bind(user.id)
    .all<ProfileRow>();
  let profiles = profileResult.results ?? [];

  if (profiles.length === 0) {
    const profileId = `prf_${randomHex(10)}`;
    await env.DB.prepare(
      `INSERT INTO profiles
         (id, user_id, name, avatar_color, is_kids, pin_hash, pin_attempts, pin_locked_until, created_at)
       VALUES (?, ?, ?, ?, 0, NULL, 0, 0, ?)`
    )
      .bind(profileId, user.id, "You", DEFAULT_AVATAR, now)
      .run();

    profileResult = await env.DB.prepare(
      "SELECT * FROM profiles WHERE user_id = ? ORDER BY created_at ASC"
    )
      .bind(user.id)
      .all<ProfileRow>();
    profiles = profileResult.results ?? [];
  }

  const token = randomHex(32);
  const tokenHash = await sha256(token);

  await env.DB.prepare(
    `INSERT INTO sessions (token_hash, user_id, created_at, expires_at)
     VALUES (?, ?, ?, ?)`
  )
    .bind(tokenHash, user.id, now, now + SESSION_TTL_MS)
    .run();

  await env.DB.prepare(
    `DELETE FROM login_codes
     WHERE identifier = ? AND (consumed_at IS NOT NULL OR expires_at < ?)`
  )
    .bind(identifier.value, now - 24 * 60 * 60 * 1000)
    .run();

  return json({
    token,
    account: publicUser(user),
    profiles: profiles.map(publicProfile),
    isNewUser
  });
}

async function logout(request: Request, env: Env): Promise<Response> {
  const header = request.headers.get("authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";

  if (token) {
    const tokenHash = await sha256(token);
    await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?")
      .bind(tokenHash)
      .run();
  }

  return json({ ok: true });
}

export async function handleAuth(
  request: Request,
  env: Env,
  url: URL
): Promise<Response> {
  const method = request.method.toUpperCase();

  if (url.pathname === "/v1/auth/request-code" && method === "POST") {
    return requestCode(request, env);
  }

  if (url.pathname === "/v1/auth/verify" && method === "POST") {
    return verifyCode(request, env);
  }

  if (url.pathname === "/v1/auth/logout" && method === "POST") {
    return logout(request, env);
  }

  throw new HttpError(404, "Not found.");
}
