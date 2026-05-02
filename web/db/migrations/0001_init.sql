-- Schema for the D4Mac storefront database.
-- The app self-applies this on the first /api/download hit via
-- `ensureSchema()` in `web/lib/db.ts`. This file documents the schema
-- and lets you bootstrap manually with:
--
--   psql $DATABASE_URL -f web/db/migrations/0001_init.sql

CREATE TABLE IF NOT EXISTS downloads (
  id INTEGER PRIMARY KEY,
  count BIGINT NOT NULL DEFAULT 0
);
