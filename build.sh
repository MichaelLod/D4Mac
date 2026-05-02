#!/usr/bin/env bash
# Assemble D4Mac.app bundle from Swift sources + wine-cx26.1 runtime.
#
# Layout produced:
#   build/D4Mac.app/Contents/
#     Info.plist
#     MacOS/D4Mac                          (Swift binary)
#     Resources/AppIcon.icns               (placeholder until icon exists)
#     Resources/Apple-GPTK-License.pdf     (if available)
#     SharedSupport/Wine/                  (copy of wine-cx26.1)
#
# Args:
#   --release    swift build -c release (slower, optimised)
#   --notarize   after build, codesign + notarize via stored credentials
#                (requires APPLE_DEV_ID + APPLE_NOTARY_PROFILE)
#   --dmg        wrap built .app in a .dmg with /Applications shortcut.
#                Combine with --notarize to also sign + staple the DMG.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WINE_RUNTIME="$ROOT/wine-cx26.1"
BUILD="$SCRIPT_DIR/build"
APP="$BUILD/D4Mac.app"

CONFIG="debug"
NOTARIZE=0
DMG=0
for arg in "$@"; do
  case "$arg" in
    --release)  CONFIG="release" ;;
    --notarize) NOTARIZE=1; CONFIG="release" ;;
    --dmg)      DMG=1 ;;
    -h|--help)  sed -n '1,22p' "$0"; exit 0 ;;
  esac
done

[ -d "$WINE_RUNTIME" ] || { echo "error: $WINE_RUNTIME missing" >&2; exit 1; }
[ -f "$WINE_RUNTIME/bin/wine" ] || { echo "error: wine binary missing in runtime" >&2; exit 1; }

echo "==> swift build ($CONFIG)"
cd "$SCRIPT_DIR"
swift build -c "$CONFIG"
BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)
SWIFT_BIN="$BIN_PATH/D4Mac"
[ -f "$SWIFT_BIN" ] || { echo "error: built binary missing at $SWIFT_BIN" >&2; exit 1; }

# Sparkle ships as a SwiftPM binaryTarget (an xcframework). Pick the macOS
# slice and embed it in Contents/Frameworks/. Glob across the Sparkle dir so
# version bumps don't break the path.
SPARKLE_FRAMEWORK=$(find "$SCRIPT_DIR/.build/artifacts" \
  -path "*Sparkle.xcframework/macos*/Sparkle.framework" \
  -type d 2>/dev/null | head -1)
[ -d "$SPARKLE_FRAMEWORK" ] || { echo "error: Sparkle.framework not found in build artifacts (run 'swift package resolve'?)" >&2; exit 1; }

echo "==> assemble bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/SharedSupport" "$APP/Contents/Frameworks"

cp -p "$SCRIPT_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -p "$SWIFT_BIN" "$APP/Contents/MacOS/D4Mac"

# Embed Sparkle so the Mach-O binary's @rpath/Sparkle.framework load resolves.
cp -cR "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
# `swift build` doesn't add the bundled-frameworks rpath; install_name_tool
# gives the binary a path that resolves once the .app is assembled.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "$APP/Contents/MacOS/D4Mac" 2>/dev/null || true

# Optional license artifacts (skipped silently if absent for now).
for f in "$SCRIPT_DIR/LICENSES/Apple-GPTK-License.pdf" \
         "$SCRIPT_DIR/Resources/AppIcon.icns"; do
  if [ -f "$f" ]; then cp -p "$f" "$APP/Contents/Resources/"; fi
done

# Bundled Windows prerequisites (run silently before any user installer).
PREREQ_SRC="$SCRIPT_DIR/Prereqs"
PREREQ_DST="$APP/Contents/Resources/Prereqs"
mkdir -p "$PREREQ_DST"
for f in vc_redist.x64.exe vc_redist.x86.exe; do
  if [ -f "$PREREQ_SRC/$f" ]; then
    cp -p "$PREREQ_SRC/$f" "$PREREQ_DST/$f"
    echo "bundled prereq: $f"
  else
    echo "warning: missing $PREREQ_SRC/$f — bottle setup will skip $f"
  fi
done

# Bundled fonts — copied as-is into bottle/drive_c/windows/Fonts at install
# time. Set mirrors what CrossOver ships in their BNet bottle: MS Core Fonts
# For The Web with the original Windows-expected filenames, plus Source Han
# Sans for CJK rendering. APFS clone keeps the build cheap.
#
# MS Core Fonts (.TTF) are gitignored — Microsoft's 1996 EULA permits the
# original installers but not the raw .TTF files, so we fetch + extract on
# demand. Source Han Sans (.otf) is SIL OFL and committed.
FONTS_SRC="$SCRIPT_DIR/Resources/Fonts"
FONTS_DST="$APP/Contents/Resources/Fonts"
if [ -d "$FONTS_SRC" ]; then
  # `cabextract -L` (in fetch.sh) writes lowercase, so the marker file is
  # arial.ttf, not arial.TTF.
  if ! ls "$FONTS_SRC"/arial.ttf >/dev/null 2>&1; then
    echo "==> fetching Microsoft Core Fonts (one-time, ~16 MB)"
    "$FONTS_SRC/fetch.sh"
  fi
  cp -cR "$FONTS_SRC" "$FONTS_DST"
  # Don't ship fetch.sh + license files inside the .app bundle.
  rm -f "$FONTS_DST/fetch.sh" "$FONTS_DST"/LICENSE-*.txt
  echo "bundled fonts ($(ls "$FONTS_DST" | wc -l | tr -d ' ') files, $(du -sh "$FONTS_DST" | awk '{print $1}'))"
else
  echo "warning: missing $FONTS_SRC — bottle setup will skip font deploy"
fi

echo "==> copy Wine runtime ($(du -sh "$WINE_RUNTIME" | awk '{print $1}'))"
# clone-on-write copy; on APFS this is instant + zero extra disk.
cp -cR "$WINE_RUNTIME" "$APP/Contents/SharedSupport/Wine"

# Strip stale upgrade leftovers — *.bak files (from past MoltenVK swaps)
# and *.before-* symlinks aren't shippable: notarization rejects them.
find "$APP/Contents/SharedSupport/Wine" \
  \( -name "*.bak" -o -name "*.before-*" \) -delete

# Make sure binaries are executable post-copy.
chmod +x "$APP/Contents/MacOS/D4Mac"
find "$APP/Contents/SharedSupport/Wine/bin" -type f -exec chmod +x {} +

# Ad-hoc sign so Gatekeeper allows local launch in debug.
echo "==> ad-hoc codesign"
codesign --force --deep --sign - "$APP" 2>&1 | head -5 || true

echo
echo "✓ built $APP"
echo "  size: $(du -sh "$APP" | awk '{print $1}')"
echo
echo "to launch:"
echo "  open '$APP'"
echo

if [ "$NOTARIZE" = "1" ]; then
  : "${APPLE_DEV_ID:?APPLE_DEV_ID env var must hold the Developer ID Application identity}"
  : "${APPLE_NOTARY_PROFILE:?APPLE_NOTARY_PROFILE must name a stored notarytool keychain profile}"

  echo "==> Developer ID codesign + notarize"
  # Sign every Mach-O inside the bundle (Wine ships ~hundreds), then the .app
  # itself. --deep alone is unreliable for nested bundles; iterate explicitly.
  ENTITLEMENTS="$SCRIPT_DIR/Resources/D4Mac.entitlements"
  find "$APP/Contents" \( -name "*.dylib" -o -name "*.so" -o -name "*.framework" \) \
    -not -path "*/Sparkle.framework*" \
    -not -path "*/D3DMetal.framework*" \
    -exec codesign --force --options runtime --timestamp \
      --sign "$APPLE_DEV_ID" --entitlements "$ENTITLEMENTS" {} \; 2>/dev/null || true
  find "$APP/Contents/SharedSupport/Wine/bin" -type f -perm -u+x \
    -exec codesign --force --options runtime --timestamp \
      --sign "$APPLE_DEV_ID" --entitlements "$ENTITLEMENTS" {} \; 2>/dev/null || true
  # Wine ships executable loaders under lib/wine/x86_64-unix/ that have no
  # extension (e.g. the bare `wine` binary) — Apple's notary rejects them
  # unsigned. Catch every executable mach-o here regardless of name.
  find "$APP/Contents/SharedSupport/Wine/lib/wine" -type f -perm -u+x \
    -exec codesign --force --options runtime --timestamp \
      --sign "$APPLE_DEV_ID" --entitlements "$ENTITLEMENTS" {} \; 2>/dev/null || true
  # Apple's D3DMetal.framework needs a deep re-sign with our Developer ID
  # for redistribution — same pattern as Sparkle. Shallow sign corrupts the
  # nested signatures.
  D3DMETAL="$APP/Contents/SharedSupport/Wine/lib/external/D3DMetal.framework"
  if [ -d "$D3DMETAL" ]; then
    codesign --force --deep --options runtime --timestamp \
      --sign "$APPLE_DEV_ID" \
      "$D3DMETAL"
  fi
  # Sparkle.framework contains its own helpers (Autoupdate, Updater.app,
  # XPCServices). They must be signed with hardened runtime but no app
  # entitlements; --deep signs the nested binaries in one pass.
  codesign --force --deep --options runtime --timestamp \
    --sign "$APPLE_DEV_ID" \
    "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --deep --options runtime --timestamp \
    --sign "$APPLE_DEV_ID" \
    --entitlements "$ENTITLEMENTS" \
    "$APP"

  ZIP="$BUILD/D4Mac.zip"
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  echo "✓ notarized"

  # Build the Sparkle update artifact + appcast.xml. The zip is taken AFTER
  # stapling so the offline ticket is baked in (Sparkle clients may install
  # without re-contacting Apple).
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
  UPDATE_ZIP="$BUILD/D4Mac-$VERSION.zip"
  /usr/bin/ditto -c -k --keepParent "$APP" "$UPDATE_ZIP"

  # Default SPARKLE_BIN to the canonical extracted location.
  : "${SPARKLE_BIN:=$HOME/.local/sparkle/bin}"
  if [ -x "$SPARKLE_BIN/generate_appcast" ]; then
    APPCAST_DIR="$BUILD/appcast-staging"
    rm -rf "$APPCAST_DIR"; mkdir -p "$APPCAST_DIR"
    cp -p "$UPDATE_ZIP" "$APPCAST_DIR/"
    # Enclosure URL prefix is the per-release GitHub asset path. Each release
    # gets its own appcast.xml that lists only that release's zip — older
    # versions don't appear, since clients always pull the latest appcast via
    # /releases/latest/download/appcast.xml.
    "$SPARKLE_BIN/generate_appcast" \
      --download-url-prefix "https://github.com/MichaelLod/D4Mac/releases/download/v$VERSION/" \
      "$APPCAST_DIR"
    cp "$APPCAST_DIR/appcast.xml" "$BUILD/appcast.xml"
    rm -rf "$APPCAST_DIR"
    echo "✓ appcast.xml + $UPDATE_ZIP ready"
  else
    echo "warning: $SPARKLE_BIN/generate_appcast missing — skipping appcast generation"
    echo "  fix: download Sparkle release tarball into ~/.local/sparkle, or export SPARKLE_BIN"
  fi
fi

if [ "$DMG" = "1" ]; then
  DMG_PATH="$BUILD/D4Mac.dmg"
  STAGING="$BUILD/dmg-staging"
  echo "==> assemble DMG at $DMG_PATH"

  rm -rf "$STAGING" "$DMG_PATH"
  mkdir -p "$STAGING"
  # APFS clone (instant, zero extra disk) — the .app inside the staging dir
  # is what gets baked into the read-only DMG image.
  cp -cR "$APP" "$STAGING/D4Mac.app"
  ln -s /Applications "$STAGING/Applications"

  hdiutil create \
    -volname "D4Mac" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

  rm -rf "$STAGING"

  # Sign the DMG itself if we have a Developer ID; otherwise leave ad-hoc.
  if [ "$NOTARIZE" = "1" ] && [ -n "${APPLE_DEV_ID:-}" ]; then
    codesign --force --sign "$APPLE_DEV_ID" --timestamp "$DMG_PATH"
    if [ -n "${APPLE_NOTARY_PROFILE:-}" ]; then
      echo "==> notarize DMG"
      xcrun notarytool submit "$DMG_PATH" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
      xcrun stapler staple "$DMG_PATH"
    fi
  fi

  echo
  echo "✓ DMG: $DMG_PATH ($(du -h "$DMG_PATH" | awk '{print $1}'))"
fi

if [ "$NOTARIZE" = "1" ] && [ -f "$BUILD/appcast.xml" ]; then
  echo
  echo "==> publish to GitHub Releases:"
  ASSETS=("$BUILD/D4Mac-$VERSION.zip" "$BUILD/appcast.xml")
  [ "$DMG" = "1" ] && ASSETS+=("$BUILD/D4Mac.dmg")
  echo "  gh release create v$VERSION \\"
  for a in "${ASSETS[@]}"; do echo "    \"$a\" \\"; done
  echo "    --repo MichaelLod/D4Mac --title \"v$VERSION\" --notes \"…\""
  echo
  echo "  (or for an existing release: gh release upload v$VERSION ...)"
fi
