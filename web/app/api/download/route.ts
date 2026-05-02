import { NextResponse } from "next/server";
import { incrementDownloads } from "@/lib/downloads";

/// `GET /api/download` increments the counter and 302-redirects to the
/// release URL. Set `D4MAC_RELEASE_URL` to a Railway Bucket / R2 / static
/// download URL pointing at the latest signed `.dmg`.
export async function GET() {
  const target = process.env.D4MAC_RELEASE_URL;
  if (!target) {
    return NextResponse.json(
      { error: "Release not configured. Set D4MAC_RELEASE_URL." },
      { status: 503 },
    );
  }
  const newCount = await incrementDownloads();
  console.log("download_click", {
    target,
    count: newCount,
    ts: new Date().toISOString(),
  });
  return NextResponse.redirect(target, 302);
}
