import { NextResponse } from "next/server";

const REPO = "MichaelLod/D4Mac";
const ASSET = "D4Mac.dmg";

/// `GET /api/download` — 302-redirects to the latest release's `D4Mac.dmg`
/// asset on GitHub. Counts toward GitHub's per-asset `download_count`,
/// which we read back via `lib/downloads.ts`.
///
/// We could link the homepage button straight at GitHub, but routing
/// through `/api/download` keeps a clean URL we control and lets us add
/// logging or version pinning later without touching the UI.
export async function GET() {
  return NextResponse.redirect(
    `https://github.com/${REPO}/releases/latest/download/${ASSET}`,
    302,
  );
}
