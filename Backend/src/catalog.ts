import { CURATED } from "./curated";
import type { CuratedTitle } from "./curated";
import type {
  CatalogRow,
  ContinueWatchingItem,
  Env,
  HomePayload,
  MediaTitle,
  ProfileRow,
  ProgressRow
} from "./types";

interface IAFile {
  name?: string;
  format?: string;
  size?: string;
}

interface IAResponse {
  files?: IAFile[];
  metadata?: Record<string, unknown>;
}

const HERO_ID = "charade-1963-cary-grant-audrey-hepburn-comedy-mystery-romance-thriller-full-movie";
const CATALOG_CACHE_KEY = "catalog:v4";
const CATALOG_TTL_SECONDS = 60 * 60;
const IA_TTL_SECONDS = 12 * 60 * 60;

const KIDS_GENRES = new Set([
  "family",
  "animation",
  "comedy",
  "adventure",
  "short"
]);

const KIDS_BLOCKED_GENRES = new Set([
  "horror",
  "thriller",
  "crime",
  "film noir",
  "war",
  "mystery"
]);

function isKidFriendly(title: MediaTitle): boolean {
  if (title.tags.includes("kids")) return true;
  const genres = title.genres.map((genre) => genre.toLowerCase());
  const hasAllowed = genres.some((genre) => KIDS_GENRES.has(genre));
  const hasBlocked = genres.some((genre) => KIDS_BLOCKED_GENRES.has(genre));
  return hasAllowed && !hasBlocked;
}

export function filterForProfile(catalog: MediaTitle[], profile: ProfileRow | null): MediaTitle[] {
  if (!profile || profile.is_kids !== 1) {
    return catalog;
  }
  return catalog.filter(isKidFriendly);
}

let memoryCatalog: { titles: MediaTitle[]; expiresAt: number } | null = null;

function firstString(value: unknown): string | null {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }
  if (Array.isArray(value)) {
    const found = value.find((entry) => typeof entry === "string" && entry.trim());
    return typeof found === "string" ? found : null;
  }
  return null;
}

function pickStream(files: IAFile[]): IAFile | null {
  const candidates = files.filter(
    (file) =>
      typeof file.name === "string" &&
      /\.(mp4|m4v)$/i.test(file.name) &&
      !/\.(ogv|webm|mpg|avi|mov)$/i.test(file.name)
  );

  if (candidates.length === 0) {
    return null;
  }

  const score = (file: IAFile): number => {
    const name = (file.name ?? "").toLowerCase();
    const format = (file.format ?? "").toLowerCase();
    const size = Number(file.size ?? 0);
    let value = 0;

    if (format.includes("h.264")) value += 6;
    if (format.includes("mpeg4")) value += 3;
    if (name.endsWith(".ia.mp4")) value += 2;
    if (name.includes("512kb")) value -= 3;
    if (name.includes("1080p") || name.includes("720p")) value += 1;
    if (size > 0 && size <= 1_200_000_000) value += 4;
    if (size > 2_000_000_000) value -= 4;
    if (size > 3_000_000_000) value -= 4;

    return value;
  };

  return [...candidates].sort((a, b) => {
    const scoreDelta = score(b) - score(a);
    if (scoreDelta !== 0) return scoreDelta;
    return Number(a.size ?? 0) - Number(b.size ?? 0);
  })[0];
}

function buildTitle(curated: CuratedTitle, meta: IAResponse | null): MediaTitle {
  const file = pickStream(meta?.files ?? []);
  const encodedId = encodeURIComponent(curated.id);
  const streamURL = file?.name
    ? `https://archive.org/download/${encodedId}/${encodeURIComponent(file.name)}`
    : null;
  const licenseURL =
    firstString(meta?.metadata?.licenseurl) ??
    `https://archive.org/details/${encodedId}`;

  return {
    id: curated.id,
    title: curated.title,
    year: curated.year,
    overview: curated.blurb,
    genres: curated.genres,
    runtimeMinutes: curated.runtimeMinutes,
    posterURL: `https://archive.org/services/img/${encodedId}`,
    backdropURL: `https://archive.org/services/img/${encodedId}`,
    streamURL,
    rating: curated.rating,
    source: "Internet Archive",
    licenseURL,
    tags: curated.tags
  };
}

async function resolveTitle(env: Env, curated: CuratedTitle): Promise<MediaTitle> {
  const cacheKey = `ia:v4:${curated.id}`;

  if (env.CACHE) {
    try {
      const cached = (await env.CACHE.get(cacheKey, "json")) as MediaTitle | null;
      if (cached) return cached;
    } catch {
      // KV is an optimization, never a hard dependency.
    }
  }

  let meta: IAResponse | null = null;
  try {
    const response = await fetch(
      `https://archive.org/metadata/${encodeURIComponent(curated.id)}`,
      { cf: { cacheTtl: 3600, cacheEverything: true } }
    );
    if (response.ok) {
      meta = (await response.json()) as IAResponse;
    }
  } catch (error) {
    console.error("Archive metadata failed", curated.id, error);
  }

  const title = buildTitle(curated, meta);

  if (env.CACHE) {
    try {
      await env.CACHE.put(cacheKey, JSON.stringify(title), {
        expirationTtl: title.streamURL ? IA_TTL_SECONDS : 300
      });
    } catch {
      // Ignore cache write failures.
    }
  }

  return title;
}

async function mapLimit<T, R>(
  items: T[],
  limit: number,
  mapper: (item: T) => Promise<R>
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let cursor = 0;

  const workers = Array.from(
    { length: Math.min(limit, items.length) },
    async () => {
      while (true) {
        const index = cursor;
        cursor += 1;
        if (index >= items.length) return;
        results[index] = await mapper(items[index]);
      }
    }
  );

  await Promise.all(workers);
  return results;
}

export async function getCatalog(env: Env): Promise<MediaTitle[]> {
  if (memoryCatalog && memoryCatalog.expiresAt > Date.now()) {
    return memoryCatalog.titles;
  }

  if (env.CACHE) {
    try {
      const cached = (await env.CACHE.get(CATALOG_CACHE_KEY, "json")) as MediaTitle[] | null;
      if (cached && cached.length > 0) {
        memoryCatalog = {
          titles: cached,
          expiresAt: Date.now() + 5 * 60 * 1000
        };
        return cached;
      }
    } catch {
      // Fall through to a live build.
    }
  }

  const titles = await mapLimit(CURATED, 6, (curated) => resolveTitle(env, curated));

  if (env.CACHE) {
    try {
      await env.CACHE.put(CATALOG_CACHE_KEY, JSON.stringify(titles), {
        expirationTtl: CATALOG_TTL_SECONDS
      });
    } catch {
      // Ignore.
    }
  }

  memoryCatalog = {
    titles,
    expiresAt: Date.now() + 5 * 60 * 1000
  };

  return titles;
}

function curatedById(): Map<string, CuratedTitle> {
  return new Map(CURATED.map((title) => [title.id, title]));
}

export async function buildHome(
  env: Env,
  profile: ProfileRow | null
): Promise<HomePayload> {
  const allTitles = await getCatalog(env);
  const catalog = filterForProfile(allTitles, profile);
  const curated = curatedById();
  const byId = new Map(catalog.map((title) => [title.id, title]));

  const rows: CatalogRow[] = [];

  const addRow = (
    id: string,
    title: string,
    filter: (item: MediaTitle) => boolean,
    sorter?: (a: MediaTitle, b: MediaTitle) => number
  ) => {
    let items = catalog.filter(filter);
    if (sorter) items = [...items].sort(sorter);
    items = items.slice(0, 20);
    if (items.length > 0) {
      rows.push({ id, title, items });
    }
  };

  addRow(
    "trending",
    "Trending Now",
    () => true,
    (a, b) =>
      (curated.get(b.id)?.popularity ?? 0) -
      (curated.get(a.id)?.popularity ?? 0)
  );
  addRow("essentials", "Nova Essentials", (item) => item.tags.includes("essential"));
  addRow("noir", "Film Noir", (item) => item.genres.includes("Film Noir"));
  addRow("scifi", "Sci-Fi & Creature Features", (item) => item.genres.includes("Sci-Fi"));
  addRow("horror", "Horror After Dark", (item) => item.genres.includes("Horror"));
  addRow("comedy", "Comedy", (item) => item.genres.includes("Comedy"));
  addRow("silent", "The Silent Era", (item) => item.tags.includes("silent"));
  addRow(
    "drama",
    "Drama & War",
    (item) => item.genres.includes("Drama") || item.genres.includes("War")
  );
  addRow("family", "Family Matinee", (item) => item.genres.includes("Family"));
  addRow("adventure", "Adventure", (item) => item.genres.includes("Adventure"));

  const hero =
    catalog.find((item) => item.id === HERO_ID && item.streamURL) ??
    catalog.find((item) => item.tags.includes("featured") && item.streamURL) ??
    catalog.find((item) => item.streamURL) ??
    catalog[0] ??
    null;

  let continueWatching: ContinueWatchingItem[] = [];

  if (profile) {
    const result = await env.DB.prepare(
      `SELECT * FROM progress
       WHERE profile_id = ?
       ORDER BY updated_at DESC
       LIMIT 12`
    )
      .bind(profile.id)
      .all<ProgressRow>();

    continueWatching = (result.results ?? [])
      .map((row) => {
        const title = byId.get(row.title_id);
        if (!title) return null;
        return {
          title,
          positionSeconds: row.position_seconds,
          durationSeconds: row.duration_seconds
        };
      })
      .filter((item): item is ContinueWatchingItem => item !== null);
  }

  return { hero, rows, continueWatching };
}

export async function searchCatalog(
  env: Env,
  query: string,
  profile: ProfileRow | null = null
): Promise<MediaTitle[]> {
  const allTitles = await getCatalog(env);
  const catalog = filterForProfile(allTitles, profile);
  const normalized = query.trim().toLowerCase();

  if (!normalized) return [];

  return catalog
    .filter((item) => {
      const haystack = [
        item.title,
        item.overview,
        item.genres.join(" "),
        item.tags.join(" "),
        item.year?.toString() ?? ""
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(normalized);
    })
    .slice(0, 60);
}

export async function getTitleById(env: Env, id: string): Promise<MediaTitle | null> {
  const catalog = await getCatalog(env);
  return catalog.find((item) => item.id === id) ?? null;
}

export function isKnownTitle(id: string): boolean {
  return CURATED.some((item) => item.id === id);
}
