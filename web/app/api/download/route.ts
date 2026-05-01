import { NextResponse } from "next/server";
import { getReleaseStats } from "@/lib/github";
import { githubReleasesUrl } from "@/lib/config";

export async function GET() {
  const stats = await getReleaseStats();
  const target = stats.latestAssetUrl ?? githubReleasesUrl;
  console.log("download_click", {
    target,
    version: stats.latestVersion,
    ts: new Date().toISOString(),
  });
  return NextResponse.redirect(target, 302);
}
