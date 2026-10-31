export interface Env {
  DB: D1Database;
  CACHE?: KVNamespace;
  CODE_PEPPER: string;
  DEV_RETURN_CODE?: string;
  RESEND_API_KEY?: string;
  BREVO_API_KEY?: string;
  EMAIL_FROM?: string;
  TWILIO_ACCOUNT_SID?: string;
  TWILIO_AUTH_TOKEN?: string;
  TWILIO_FROM?: string;
  APP_ORIGIN?: string;
}

export interface UserRow {
  id: string;
  identifier: string;
  email: string | null;
  phone: string | null;
  name: string;
  created_at: number;
}

export interface ProfileRow {
  id: string;
  user_id: string;
  name: string;
  avatar_color: string;
  is_kids: number;
  pin_hash: string | null;
  pin_attempts: number;
  pin_locked_until: number;
  created_at: number;
}

export interface LoginCodeRow {
  id: string;
  identifier: string;
  channel: "email" | "sms";
  code_hash: string;
  expires_at: number;
  attempts: number;
  consumed_at: number | null;
  created_at: number;
  ip: string | null;
}

export interface ProgressRow {
  profile_id: string;
  title_id: string;
  position_seconds: number;
  duration_seconds: number;
  updated_at: number;
}

export interface PublicUser {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  createdAt: number;
}

export interface Profile {
  id: string;
  name: string;
  avatarColor: string;
  isKids: boolean;
  hasPin: boolean;
  createdAt: number;
}

export interface MediaTitle {
  id: string;
  title: string;
  year: number | null;
  overview: string;
  genres: string[];
  runtimeMinutes: number | null;
  posterURL: string;
  backdropURL: string;
  streamURL: string | null;
  rating: number | null;
  source: string;
  licenseURL: string;
  tags: string[];
}

export interface CatalogRow {
  id: string;
  title: string;
  items: MediaTitle[];
}

export interface ContinueWatchingItem {
  title: MediaTitle;
  positionSeconds: number;
  durationSeconds: number;
}

export interface HomePayload {
  hero: MediaTitle | null;
  rows: CatalogRow[];
  continueWatching: ContinueWatchingItem[];
}

export function publicUser(user: UserRow): PublicUser {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    createdAt: user.created_at
  };
}

export function publicProfile(profile: ProfileRow): Profile {
  return {
    id: profile.id,
    name: profile.name,
    avatarColor: profile.avatar_color,
    isKids: profile.is_kids === 1,
    hasPin: Boolean(profile.pin_hash),
    createdAt: profile.created_at
  };
}
