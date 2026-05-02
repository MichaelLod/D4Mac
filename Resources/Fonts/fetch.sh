#!/usr/bin/env bash
# Fetches Microsoft Core Fonts For The Web from the SourceForge Wine
# corefonts mirror, where Microsoft's original 1996 EULA-permitted
# .exe installers are still hosted unmodified. We extract the .TTF
# files out of each CAB so Wine bottles can find them by name.
#
# These fonts are needed by Battle.net's CEF renderer (Arial in
# particular) and are not redistributable in raw .TTF form, hence
# this fetch step instead of bundling them in the repo.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MIRROR="https://downloads.sourceforge.net/corefonts"
PACKAGES=(
  andale32.exe   # Andale Mono
  arial32.exe    # Arial (regular/bold/italic/bold-italic)
  arialb32.exe   # Arial Black
  comic32.exe    # Comic Sans MS
  courie32.exe   # Courier New
  georgi32.exe   # Georgia
  impact32.exe   # Impact
  times32.exe    # Times New Roman
  trebuc32.exe   # Trebuchet MS
  verdan32.exe   # Verdana
  webdin32.exe   # Webdings
)

if ! command -v cabextract >/dev/null 2>&1; then
  echo "Error: cabextract not installed." >&2
  echo "  brew install cabextract" >&2
  exit 1
fi

echo "Fetching Microsoft Core Fonts to $DIR …"
for pkg in "${PACKAGES[@]}"; do
  echo "  → $pkg"
  curl -fsSL --retry 3 "$MIRROR/$pkg" -o "$TMP/$pkg"
  cabextract -L -d "$DIR" -F "*.TTF" "$TMP/$pkg" >/dev/null
done

echo ""
echo "✓ Done."
echo ""
echo "Note: msyh.ttc (Microsoft YaHei) and simsun.ttc (SimSun) are not"
echo "auto-fetched — Microsoft does not redistribute them. Battle.net works"
echo "fine without them; the bundled Source Han Sans (free, SIL OFL) is"
echo "used as a CJK fallback. If you specifically need msyh/simsun, copy"
echo "them from C:\\Windows\\Fonts\\ on a Windows install into this folder."
