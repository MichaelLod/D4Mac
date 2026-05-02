import { ensureSchema, getDb, isDbConfigured } from "./db";

/// Returns the current download count, or `null` when the database
/// isn't configured (so callers can render "—" instead of a stale 0).
export async function getDownloadCount(): Promise<number | null> {
  if (!isDbConfigured()) return null;
  try {
    await ensureSchema();
    const sql = getDb();
    const rows = await sql<{ count: number }[]>`
      SELECT count FROM downloads WHERE id = 1
    `;
    return Number(rows[0]?.count ?? 0);
  } catch (err) {
    console.warn("downloads.getCount failed", err);
    return null;
  }
}

/// Atomic +1 to the counter. Inserts the row on first call.
/// Returns the new value, or `null` when the database isn't configured.
export async function incrementDownloads(): Promise<number | null> {
  if (!isDbConfigured()) return null;
  try {
    await ensureSchema();
    const sql = getDb();
    const rows = await sql<{ count: number }[]>`
      INSERT INTO downloads (id, count) VALUES (1, 1)
      ON CONFLICT (id) DO UPDATE SET count = downloads.count + 1
      RETURNING count
    `;
    return Number(rows[0].count);
  } catch (err) {
    console.warn("downloads.increment failed", err);
    return null;
  }
}
