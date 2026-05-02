const REPO = "MichaelLod/D4Mac";

/// Returns total download count across all release assets, or `null` on
/// failure / if the repo has no releases yet.
///
/// Replaces the old Postgres counter with GitHub's per-asset counter.
/// Cached on the page via `revalidate = 60`, so this fetch fires at most
/// once per minute even under heavy traffic.
export async function getDownloadCount(): Promise<number | null> {
  try {
    const res = await fetch(`https://api.github.com/repos/${REPO}/releases`, {
      headers: {
        Accept: "application/vnd.github+json",
        "User-Agent": "d4mac.com",
      },
      next: { revalidate: 300 },
    });
    if (!res.ok) return null;
    const releases = (await res.json()) as Array<{
      assets: Array<{ download_count: number }>;
    }>;
    return releases.reduce(
      (sum, r) =>
        sum + r.assets.reduce((s, a) => s + (a.download_count ?? 0), 0),
      0,
    );
  } catch (err) {
    console.warn("downloads.getCount failed", err);
    return null;
  }
}
