import postgres from "postgres";

let _sql: ReturnType<typeof postgres> | null = null;
let _ensured = false;

export function isDbConfigured(): boolean {
  return !!process.env.DATABASE_URL;
}

export function getDb(): ReturnType<typeof postgres> {
  if (_sql) return _sql;
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL not set");
  _sql = postgres(url, {
    // Railway pooler handles concurrency. Keep low conn count for serverless.
    max: 1,
    idle_timeout: 20,
    connect_timeout: 10,
    onnotice: () => {},
  });
  return _sql;
}

/// Idempotently create the `downloads` table on first call.
/// CREATE TABLE IF NOT EXISTS is idempotent and cheap (~1 ms).
export async function ensureSchema(): Promise<void> {
  if (_ensured) return;
  const sql = getDb();
  await sql`
    CREATE TABLE IF NOT EXISTS downloads (
      id INTEGER PRIMARY KEY,
      count BIGINT NOT NULL DEFAULT 0
    )
  `;
  _ensured = true;
}
