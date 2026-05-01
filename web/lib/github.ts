import { SITE } from "./config";

export type ReleaseStats = {
  totalDownloads: number;
  latestVersion: string | null;
  latestReleaseUrl: string | null;
  latestAssetUrl: string | null;
};

type GitHubRelease = {
  tag_name: string;
  html_url: string;
  draft: boolean;
  prerelease: boolean;
  assets: Array<{
    name: string;
    browser_download_url: string;
    download_count: number;
  }>;
};

const EMPTY: ReleaseStats = {
  totalDownloads: 0,
  latestVersion: null,
  latestReleaseUrl: null,
  latestAssetUrl: null,
};

export async function getReleaseStats(): Promise<ReleaseStats> {
  const url = `https://api.github.com/repos/${SITE.github.owner}/${SITE.github.repo}/releases?per_page=100`;

  try {
    const headers: Record<string, string> = {
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    };
    if (process.env.GITHUB_TOKEN) {
      headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    }

    const res = await fetch(url, {
      headers,
      next: { revalidate: 600 },
    });

    if (!res.ok) {
      console.warn(`github releases: HTTP ${res.status}`);
      return EMPTY;
    }

    const releases = (await res.json()) as GitHubRelease[];
    const published = releases.filter((r) => !r.draft);

    const totalDownloads = published.reduce(
      (sum, r) =>
        sum + r.assets.reduce((a, asset) => a + asset.download_count, 0),
      0,
    );

    const latest = published.find((r) => !r.prerelease) ?? published[0] ?? null;
    const macAsset = latest?.assets.find(
      (a) =>
        a.name.endsWith(".dmg") ||
        a.name.endsWith(".zip") ||
        a.name.endsWith(".pkg"),
    );

    return {
      totalDownloads,
      latestVersion: latest?.tag_name ?? null,
      latestReleaseUrl: latest?.html_url ?? null,
      latestAssetUrl: macAsset?.browser_download_url ?? null,
    };
  } catch (err) {
    console.warn("github releases fetch failed", err);
    return EMPTY;
  }
}
