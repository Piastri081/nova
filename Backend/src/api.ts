import { requireUser } from "./auth";
import { buildHome, filterForProfile, getCatalog, getTitleById, isKnownTitle, searchCatalog } from "./catalog";
import { HttpError, json, readJson, requirePepper, sha256 } from "./http";
import { publicProfile, publicUser } from "./types";
import type { Env, ProfileRow, ProgressRow, UserRow } from "./types";

const MAX_PROFILES = 5;

async function listProfiles(env: Env, userId: string): Promise<ProfileRow[]> {
  const result = await env.DB.prepare(
    "SELECT * FROM profiles WHERE user_id = ? ORDER BY created_at ASC"
  )
    .bind(userId)
    .all<ProfileRow>();

  return result.results ?? [];
}

async function getProfile(
  env: Env,
  userId: string,
  profileId: string
): Promise<ProfileRow | null> {
  return env.DB.prepare(
    "SELECT * FROM profiles WHERE id = ? AND user_id = ?"
  )
    .bind(profileId, userId)
    .first<ProfileRow>();
}

async function requireProfile(
  request: Request,
  env: Env,
  user: UserRow
): Promise<ProfileRow> {
  const profileId = request.headers.get("x-nova-profile")?.trim() ?? "";
  if (!profileId) {
    throw new HttpError(400, "Choose a profile first.");
  }

  const profile = await getProfile(env, user.id, profileId);
  if (!profile) {
    throw new HttpError(403, "That profile doesn't belong to this account.");
  }

  return profile;
}

async function optionalProfile(
  request: Request,
  env: Env,
  user: UserRow
): Promise<ProfileRow | null> {
  if (!request.headers.get("x-nova-profile")?.trim()) {
    return null;
  }
  return requireProfile(request, env, user);
}

function readProfileName(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new HttpError(400, "Profile name is required.");
  }

  const name = raw.trim();
  if (name.length < 1 || name.length > 20) {
    throw new HttpError(400, "Profile names must be 1–20 characters.");
  }
  return name;
}

function readAvatarColor(raw: unknown, fallback = "#E50914"): string {
  if (raw === undefined || raw === null) return fallback;
  if (typeof raw !== "string" || !/^#[0-9a-fA-F]{6}$/.test(raw)) {
    throw new HttpError(400, "Avatar color must be a six-digit hex color.");
  }
  return raw.toUpperCase();
}

function readPin(raw: unknown): string | null {
  if (raw === undefined || raw === null || raw === "") return null;
  if (typeof raw !== "string" || !/^\d{4}$/.test(raw)) {
    throw new HttpError(400, "A profile PIN must be exactly 4 digits.");
  }
  return raw;
}

async function hashPin(env: Env, profileId: string, pin: string): Promise<string> {
  return sha256(`${requirePepper(env)}:pin:${profileId}:${pin}`);
}

async function createProfile(request: Request, env: Env, user: UserRow): Promise<Response> {
  const body = await readJson<Record<string, unknown>>(request);
  const name = readProfileName(body.name);
  const avatarColor = readAvatarColor(body.avatarColor);
  const isKids = body.isKids === true;
  const pin = readPin(body.pin);

  const existing = await listProfiles(env, user.id);
  if (existing.length >= MAX_PROFILES) {
    throw new HttpError(400, `An account can have at most ${MAX_PROFILES} profiles.`);
  }

  const profileId = `prf_${crypto.randomUUID().replace(/-/g, "").slice(0, 16)}`;
  const pinHash = pin ? await hashPin(env, profileId, pin) : null;
  const now = Date.now();

  await env.DB.prepare(
    `INSERT INTO profiles
       (id, user_id, name, avatar_color, is_kids, pin_hash, pin_attempts, pin_locked_until, created_at)
     VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)`
  )
    .bind(profileId, user.id, name, avatarColor, isKids ? 1 : 0, pinHash, now)
    .run();

  const profile = await getProfile(env, user.id, profileId);
  if (!profile) {
    throw new HttpError(500, "Could not create the profile.");
  }

  return json(publicProfile(profile));
}

async function updateProfile(
  request: Request,
  env: Env,
  user: UserRow,
  profileId: string
): Promise<Response> {
  const profile = await getProfile(env, user.id, profileId);
  if (!profile) {
    throw new HttpError(404, "Profile not found.");
  }

  const body = await readJson<Record<string, unknown>>(request);
  let name = profile.name;
  let avatarColor = profile.avatar_color;
  let isKids = profile.is_kids;
  let pinHash = profile.pin_hash;
  let pinAttempts = profile.pin_attempts;
  let pinLockedUntil = profile.pin_locked_until;

  if ("name" in body) {
    name = readProfileName(body.name);
  }
  if ("avatarColor" in body) {
    avatarColor = readAvatarColor(body.avatarColor, profile.avatar_color);
  }
  if (typeof body.isKids === "boolean") {
    isKids = body.isKids ? 1 : 0;
  }

  if (body.clearPin === true) {
    pinHash = null;
    pinAttempts = 0;
    pinLockedUntil = 0;
  } else if (typeof body.pin === "string" && body.pin.length > 0) {
    const pin = readPin(body.pin);
    if (pin) {
      pinHash = await hashPin(env, profile.id, pin);
      pinAttempts = 0;
      pinLockedUntil = 0;
    }
  }

  await env.DB.prepare(
    `UPDATE profiles
     SET name = ?, avatar_color = ?, is_kids = ?, pin_hash = ?, pin_attempts = ?, pin_locked_until = ?
     WHERE id = ? AND user_id = ?`
  )
    .bind(name, avatarColor, isKids, pinHash, pinAttempts, pinLockedUntil, profile.id, user.id)
    .run();

  return json(
    publicProfile({
      ...profile,
      name,
      avatar_color: avatarColor,
      is_kids: isKids,
      pin_hash: pinHash,
      pin_attempts: pinAttempts,
      pin_locked_until: pinLockedUntil
    })
  );
}

async function deleteProfile(
  env: Env,
  user: UserRow,
  profileId: string
): Promise<Response> {
  const profile = await getProfile(env, user.id, profileId);
  if (!profile) {
    throw new HttpError(404, "Profile not found.");
  }

  const profiles = await listProfiles(env, user.id);
  if (profiles.length <= 1) {
    throw new HttpError(400, "Keep at least one profile on the account.");
  }

  await env.DB.prepare("DELETE FROM progress WHERE profile_id = ?").bind(profile.id).run();
  await env.DB.prepare("DELETE FROM watchlist WHERE profile_id = ?").bind(profile.id).run();
  await env.DB.prepare("DELETE FROM profiles WHERE id = ? AND user_id = ?")
    .bind(profile.id, user.id)
    .run();

  return json({ ok: true });
}

async function unlockProfile(
  request: Request,
  env: Env,
  user: UserRow,
  profileId: string
): Promise<Response> {
  const profile = await getProfile(env, user.id, profileId);
  if (!profile) {
    throw new HttpError(404, "Profile not found.");
  }

  if (!profile.pin_hash) {
    return json({ ok: true });
  }

  const now = Date.now();
  if (profile.pin_locked_until > now) {
    throw new HttpError(429, "Too many attempts. Try again in a few minutes.");
  }

  const body = await readJson<{ pin?: unknown }>(request);
  const pin = readPin(body.pin);
  if (!pin) {
    throw new HttpError(400, "Enter the 4-digit PIN.");
  }

  const candidate = await hashPin(env, profile.id, pin);
  if (candidate !== profile.pin_hash) {
    const attempts = profile.pin_attempts + 1;
    const lockedUntil = attempts >= 5 ? now + 5 * 60 * 1000 : 0;

    await env.DB.prepare(
      "UPDATE profiles SET pin_attempts = ?, pin_locked_until = ? WHERE id = ?"
    )
      .bind(attempts, lockedUntil, profile.id)
      .run();

    throw new HttpError(401, "Incorrect PIN.");
  }

  await env.DB.prepare(
    "UPDATE profiles SET pin_attempts = 0, pin_locked_until = 0 WHERE id = ?"
  )
    .bind(profile.id)
    .run();

  return json({ ok: true });
}

export async function handleApi(
  request: Request,
  env: Env,
  url: URL
): Promise<Response> {
  const method = request.method.toUpperCase();
  const path = url.pathname;

  if (path === "/v1/session" && method === "GET") {
    const user = await requireUser(request, env);
    const profiles = await listProfiles(env, user.id);
    return json({
      account: publicUser(user),
      profiles: profiles.map(publicProfile)
    });
  }

  if (path === "/v1/me" && method === "GET") {
    const user = await requireUser(request, env);
    return json(publicUser(user));
  }

  if (path === "/v1/me" && method === "PATCH") {
    const user = await requireUser(request, env);
    const body = await readJson<{ name?: unknown }>(request);
    const name = readProfileName(body.name);

    await env.DB.prepare("UPDATE users SET name = ? WHERE id = ?")
      .bind(name, user.id)
      .run();

    return json(publicUser({ ...user, name }));
  }

  if (path === "/v1/me" && method === "DELETE") {
    const user = await requireUser(request, env);
    const profiles = await listProfiles(env, user.id);

    for (const profile of profiles) {
      await env.DB.prepare("DELETE FROM progress WHERE profile_id = ?")
        .bind(profile.id)
        .run();
      await env.DB.prepare("DELETE FROM watchlist WHERE profile_id = ?")
        .bind(profile.id)
        .run();
    }

    await env.DB.prepare("DELETE FROM profiles WHERE user_id = ?").bind(user.id).run();
    await env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(user.id).run();
    await env.DB.prepare("DELETE FROM login_codes WHERE identifier = ?")
      .bind(user.identifier)
      .run();
    await env.DB.prepare("DELETE FROM users WHERE id = ?").bind(user.id).run();

    return json({ ok: true });
  }

  if (path === "/v1/profiles" && method === "GET") {
    const user = await requireUser(request, env);
    const profiles = await listProfiles(env, user.id);
    return json(profiles.map(publicProfile));
  }

  if (path === "/v1/profiles" && method === "POST") {
    const user = await requireUser(request, env);
    return createProfile(request, env, user);
  }

  if (path.startsWith("/v1/profiles/")) {
    const user = await requireUser(request, env);
    const rest = decodeURIComponent(path.slice("/v1/profiles/".length));

    if (rest.endsWith("/unlock") && method === "POST") {
      const profileId = rest.slice(0, -"/unlock".length);
      return unlockProfile(request, env, user, profileId);
    }

    if (method === "PATCH") {
      return updateProfile(request, env, user, rest);
    }

    if (method === "DELETE") {
      return deleteProfile(env, user, rest);
    }
  }

  if (path === "/v1/catalog/home" && method === "GET") {
    const user = await requireUser(request, env);
    const profile = await optionalProfile(request, env, user);
    return json(await buildHome(env, profile));
  }

  if (path === "/v1/catalog/public" && method === "GET") {
    return json(await buildHome(env, null), 200, {
      "cache-control": "public, max-age=300"
    });
  }

  if (path === "/v1/catalog/search" && method === "GET") {
    const user = await requireUser(request, env);
    const profile = await optionalProfile(request, env, user);
    const query = url.searchParams.get("q") ?? "";
    return json(await searchCatalog(env, query, profile));
  }

  if (path.startsWith("/v1/titles/") && method === "GET") {
    const user = await requireUser(request, env);
    const profile = await optionalProfile(request, env, user);
    const id = decodeURIComponent(path.slice("/v1/titles/".length));
    const title = await getTitleById(env, id);
    if (!title || (profile && filterForProfile([title], profile).length === 0)) {
      throw new HttpError(404, "Title not found.");
    }
    return json(title);
  }

  if (path === "/v1/progress" && method === "GET") {
    const user = await requireUser(request, env);
    const profile = await requireProfile(request, env, user);

    const result = await env.DB.prepare(
      `SELECT * FROM progress
       WHERE profile_id = ?
       ORDER BY updated_at DESC
       LIMIT 50`
    )
      .bind(profile.id)
      .all<ProgressRow>();

    return json(
      (result.results ?? []).map((row) => ({
        titleId: row.title_id,
        positionSeconds: row.position_seconds,
        durationSeconds: row.duration_seconds,
        updatedAt: row.updated_at
      }))
    );
  }

  if (path.startsWith("/v1/progress/") && method === "PUT") {
    const user = await requireUser(request, env);
    const profile = await requireProfile(request, env, user);
    const titleId = decodeURIComponent(path.slice("/v1/progress/".length));

    if (!isKnownTitle(titleId)) {
      throw new HttpError(404, "Title not found.");
    }

    const body = await readJson<{
      positionSeconds?: unknown;
      durationSeconds?: unknown;
    }>(request);

    const position = Number(body.positionSeconds);
    const duration = Number(body.durationSeconds);

    if (
      !Number.isFinite(position) ||
      !Number.isFinite(duration) ||
      position < 0 ||
      duration <= 0
    ) {
      throw new HttpError(400, "Invalid playback position.");
    }

    const clamped = Math.min(position, duration);
    const now = Date.now();

    await env.DB.prepare(
      `INSERT INTO progress
         (profile_id, title_id, position_seconds, duration_seconds, updated_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(profile_id, title_id) DO UPDATE SET
         position_seconds = excluded.position_seconds,
         duration_seconds = excluded.duration_seconds,
         updated_at = excluded.updated_at`
    )
      .bind(profile.id, titleId, clamped, duration, now)
      .run();

    return json({
      titleId,
      positionSeconds: clamped,
      durationSeconds: duration,
      updatedAt: now
    });
  }

  if (path === "/v1/watchlist" && method === "GET") {
    const user = await requireUser(request, env);
    const profile = await requireProfile(request, env, user);

    const result = await env.DB.prepare(
      "SELECT title_id FROM watchlist WHERE profile_id = ? ORDER BY added_at DESC"
    )
      .bind(profile.id)
      .all<{ title_id: string }>();

    const catalog = filterForProfile(await getCatalog(env), profile);
    const byId = new Map(catalog.map((title) => [title.id, title]));
    const items = (result.results ?? [])
      .map((row) => byId.get(row.title_id))
      .filter((title): title is NonNullable<typeof title> => Boolean(title));

    return json(items);
  }

  if (path.startsWith("/v1/watchlist/")) {
    const user = await requireUser(request, env);
    const profile = await requireProfile(request, env, user);
    const titleId = decodeURIComponent(path.slice("/v1/watchlist/".length));

    if (!isKnownTitle(titleId)) {
      throw new HttpError(404, "Title not found.");
    }

    if (method === "POST") {
      await env.DB.prepare(
        `INSERT OR IGNORE INTO watchlist (profile_id, title_id, added_at)
         VALUES (?, ?, ?)`
      )
        .bind(profile.id, titleId, Date.now())
        .run();
      return json({ ok: true });
    }

    if (method === "DELETE") {
      await env.DB.prepare(
        "DELETE FROM watchlist WHERE profile_id = ? AND title_id = ?"
      )
        .bind(profile.id, titleId)
        .run();
      return json({ ok: true });
    }
  }

  throw new HttpError(404, "Not found.");
}
