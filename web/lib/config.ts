export const SITE = {
  name: "D4Mac",
  url: "https://d4mac.app",
  description:
    "Free, open-source Battle.net launcher for Apple Silicon Macs. Run Diablo IV and other Blizzard games natively, no CrossOver licence required.",
  shortDescription: "Free Battle.net launcher for Apple Silicon Macs.",
  github: { owner: "MichaelLod", repo: "D4Mac" },
} as const;

export const githubRepoUrl = `https://github.com/${SITE.github.owner}/${SITE.github.repo}`;
export const githubReleasesUrl = `${githubRepoUrl}/releases`;
