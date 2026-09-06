-- SANGAM Phase 1 (v3) — no auth. Device-keyed citizen reporting.
-- Consolidated schema: v2 baseline with the §2 deltas already applied
-- (no users / refresh_tokens tables anywhere).

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------- devices
CREATE TABLE IF NOT EXISTS devices (
  device_id      UUID PRIMARY KEY,
  platform       VARCHAR(10)  NOT NULL,
  reporter_name  VARCHAR(100),
  reporter_phone VARCHAR(15),
  reporter_type  VARCHAR(20)  NOT NULL DEFAULT 'CITIZEN',
  reporter_org   VARCHAR(200),
  language       VARCHAR(5)   NOT NULL DEFAULT 'hi',
  first_seen_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  last_seen_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- -------------------------------------------------------------- districts
CREATE TABLE IF NOT EXISTS districts (
  code       VARCHAR(10) PRIMARY KEY,
  name       VARCHAR(80) NOT NULL,
  state_code VARCHAR(5)  NOT NULL DEFAULT 'JH'
);

-- --------------------------------------------------------------- problems
CREATE TABLE IF NOT EXISTS problems (
  problem_id      UUID PRIMARY KEY,
  public_ref      VARCHAR(24) UNIQUE NOT NULL,
  title           VARCHAR(200) NOT NULL,
  description     TEXT         NOT NULL DEFAULT '',
  domain          VARCHAR(40)  NOT NULL,
  status          VARCHAR(30)  NOT NULL DEFAULT 'SUBMITTED',
  district_code   VARCHAR(10)  REFERENCES districts(code),
  location_label  VARCHAR(240),
  latitude        DOUBLE PRECISION,
  longitude       DOUBLE PRECISION,
  people_affected INTEGER,
  duration_label  VARCHAR(40),
  consent         BOOLEAN      NOT NULL DEFAULT FALSE,

  -- §2 deltas
  device_id       UUID         NOT NULL REFERENCES devices(device_id),
  reporter_type   VARCHAR(20)  NOT NULL DEFAULT 'CITIZEN',
  official_source BOOLEAN      NOT NULL DEFAULT FALSE,

  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_problems_device   ON problems(device_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_problems_status   ON problems(status);
CREATE INDEX IF NOT EXISTS idx_problems_district ON problems(district_code);
CREATE INDEX IF NOT EXISTS idx_problems_domain   ON problems(domain);

-- ------------------------------------------------------------------ media
CREATE TABLE IF NOT EXISTS problem_media (
  media_id     UUID PRIMARY KEY,
  problem_id   UUID NOT NULL REFERENCES problems(problem_id) ON DELETE CASCADE,
  kind         VARCHAR(10) NOT NULL,          -- photo | video | audio | doc
  storage_key  VARCHAR(300) NOT NULL,
  mime_type    VARCHAR(100),
  byte_size    BIGINT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_media_problem ON problem_media(problem_id);

-- --------------------------------------------------------- status history
CREATE TABLE IF NOT EXISTS problem_status_history (
  id         BIGSERIAL PRIMARY KEY,
  problem_id UUID NOT NULL REFERENCES problems(problem_id) ON DELETE CASCADE,
  status     VARCHAR(30) NOT NULL,
  note       TEXT,
  actor      VARCHAR(60),                     -- 'citizen' | 'system' | 'officer:<name>'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_history_problem ON problem_status_history(problem_id, created_at);

-- ------------------------------------------------- public_ref sequences
-- One counter per district so refs read JH-DMK-000417.
CREATE TABLE IF NOT EXISTS ref_counters (
  district_code VARCHAR(10) PRIMARY KEY,
  last_value    INTEGER NOT NULL DEFAULT 0
);
