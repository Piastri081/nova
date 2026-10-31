CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  identifier TEXT NOT NULL UNIQUE,
  email TEXT,
  phone TEXT,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  avatar_color TEXT NOT NULL DEFAULT '#E50914',
  is_kids INTEGER NOT NULL DEFAULT 0,
  pin_hash TEXT,
  pin_attempts INTEGER NOT NULL DEFAULT 0,
  pin_locked_until INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_profiles_user ON profiles(user_id);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS login_codes (
  id TEXT PRIMARY KEY,
  identifier TEXT NOT NULL,
  channel TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  consumed_at INTEGER,
  created_at INTEGER NOT NULL,
  ip TEXT
);

CREATE INDEX IF NOT EXISTS idx_login_codes_identifier
  ON login_codes(identifier, created_at);

CREATE TABLE IF NOT EXISTS progress (
  profile_id TEXT NOT NULL,
  title_id TEXT NOT NULL,
  position_seconds REAL NOT NULL,
  duration_seconds REAL NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (profile_id, title_id)
);

CREATE INDEX IF NOT EXISTS idx_progress_profile
  ON progress(profile_id, updated_at);

CREATE TABLE IF NOT EXISTS watchlist (
  profile_id TEXT NOT NULL,
  title_id TEXT NOT NULL,
  added_at INTEGER NOT NULL,
  PRIMARY KEY (profile_id, title_id)
);

CREATE INDEX IF NOT EXISTS idx_watchlist_profile
  ON watchlist(profile_id, added_at);
