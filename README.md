# D4Mac

> Free, open-source Battle.net launcher for Apple Silicon Macs. Run Diablo IV
> and other Blizzard games natively. No CrossOver licence. No subscription.

🌐 [d4mac.com](https://d4mac.com) · 📥 [Download latest](https://github.com/MichaelLod/D4Mac/releases/latest) · 🐛 [Report an issue](https://github.com/MichaelLod/D4Mac/issues/new/choose) · 🍺 [Buy me a beer](https://d4mac.com/#beer)

---

## What it is

A native macOS `.app` that wraps a self-contained Wine 11.0 + Apple Game
Porting Toolkit 3.0 stack, set up specifically to run Battle.net and
Diablo IV on Apple Silicon. Drag-to-Applications, double-click, log into
Battle.net, play.

The launcher itself is MIT-licensed open source. The `.app` bundle ships
third-party binaries (Wine, GPTK, DXMT, MoltenVK, MS VC++ Redist, Adobe
Source Han Sans) — see [`THIRD_PARTY_LICENSES.md`](./THIRD_PARTY_LICENSES.md)
for the full breakdown.

## Status

| Game / app                  | Status                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------- |
| Battle.net                  | ✓ launches, login + chat work, keyboard works                                               |
| Diablo IV                   | ✓ playable end-to-end (verified 2026-05)                                                    |
| First-launch shader compile | ⚠ ~50 % of the time it hangs once on the Metal pipeline race; second launch always works    |
| Other Blizzard titles       | not tested — try and [open an issue](https://github.com/MichaelLod/D4Mac/issues/new/choose) |

## Requirements

- Apple Silicon Mac (M1, M2, M3, M4 — any)
- macOS 14 (Sonoma) or later
- ~400 MB free for the `.app` bundle, plus space for the Battle.net + game install (Diablo IV is ~80 GB)
- Apple ID (only if Gatekeeper prompts you to verify the bundle on first launch)

Intel Macs are not supported and will not be — Apple's GPTK is Apple-Silicon-only.

## Install

1. Grab the latest signed `D4Mac.dmg` from the [Releases page](https://github.com/MichaelLod/D4Mac/releases/latest).
2. Open it, drag `D4Mac.app` to `/Applications`.
3. Launch it. The first run unpacks Wine and runs the Battle.net installer; it takes ~2 minutes.
4. Log in to Battle.net, install your game, play.

If a launch ever gets weird (Battle.net hangs, login fails repeatedly), open
**Settings → Reset bottle**. The reset rebuilds the bottle from the bundled
prereqs — your `D4Mac.app` itself stays untouched.

## Why this exists

Battle.net + Diablo IV on Apple Silicon already work via CrossOver, but
CrossOver is $74 and bundles features most users don't need. Apple's GPTK
is free for non-commercial redistribution, and Wine has been LGPL since
forever. There was no reason this had to cost anything — so it doesn't.

D4Mac is funded entirely by [beer tips](https://d4mac.com/#beer).
Optional, never gated, no nag.

## Build from source

```bash
git clone https://github.com/MichaelLod/D4Mac.git
cd D4Mac
Resources/Fonts/fetch.sh   # downloads MS Core Fonts (one-time)
Prereqs/fetch.sh           # downloads VC++ Redistributable (one-time)
# build.sh also auto-runs Prereqs/fetch-wine-libs.py to stage the x86_64
# FreeType/GnuTLS chain into the Wine runtime (one-time, ~8 MB from GHCR).
./build.sh                 # debug build
./build.sh --release       # optimised
./build.sh --release --notarize --dmg   # full release pipeline
```

You'll also need a built Wine 11.0 runtime staged at `../wine-cx26.1/`.
See [`THIRD_PARTY_LICENSES.md`](./THIRD_PARTY_LICENSES.md) for sources, or
the LGPL CodeWeavers release at [media.codeweavers.com/pub/crossover/source/](https://media.codeweavers.com/pub/crossover/source/).

`build.sh --release --notarize --dmg` produces a signed + notarised DMG ready for distribution. Notarisation requires:

- Developer ID Application certificate installed in your keychain
- Apple notarytool credentials saved as profile name `D4Mac` (`xcrun notarytool store-credentials D4Mac …`)

## Architecture

```
   ┌──────────────────────┐
   │   D4Mac.app (Swift)  │   SwiftUI launcher: bottle manager,
   │                      │   first-run installer, Battle.net launcher
   └──────────┬───────────┘
              │ spawns
              ▼
   ┌──────────────────────┐
   │   Wine 11.0 (LGPL)   │   PE loader, kernel32, ntdll, …
   │  + Apple GPTK 3.0    │   D3D12 / D3D11 (64-bit) → Metal forwarders
   │  + DXMT v0.72        │   D3D11 / DXGI (32-bit, BNet CEF) → Metal
   │  + MoltenVK          │   Vulkan fallback
   └──────────────────────┘
```

The whole runtime lives inside the `.app` bundle at
`Contents/SharedSupport/Wine/`. No system-wide install, no PATH
manipulation, no admin password.

## Repository layout

| Path                         | Purpose                                                                                              |
| ---------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Sources/D4Mac/`             | SwiftUI launcher source                                                                              |
| `Resources/`                 | App icon, `Info.plist`, fonts, entitlements                                                          |
| `Resources/Fonts/fetch.sh`   | One-time fetch of MS Core Fonts For The Web                                                          |
| `Prereqs/fetch.sh`           | One-time fetch of VC++ Redistributable installers                                                    |
| `Prereqs/fetch-wine-libs.py` | Stages the x86_64 FreeType/GnuTLS chain into Wine's `lib/external` (GHCR bottles)                    |
| `web/`                       | The [d4mac.com](https://d4mac.com) Next.js site (download landing page, BMC tip checkout, dashboard) |
| `build.sh`                   | Build / notarise / DMG packaging                                                                     |
| `THIRD_PARTY_LICENSES.md`    | Per-component licence breakdown                                                                      |
| `LICENSE`                    | MIT — for the launcher source only                                                                   |

## Reporting issues

Use [GitHub Issues](https://github.com/MichaelLod/D4Mac/issues/new/choose).
Include:

- macOS version (e.g. _14.5 Sonoma_)
- Mac model (e.g. _MacBook Pro M3 Pro_)
- D4Mac version (Settings → About)
- Logs from `~/Library/Logs/D4Mac/`
- Screenshots if you have them

## Licence

Launcher source: **MIT** — see [`LICENSE`](./LICENSE).

The `.app` bundle ships third-party binaries with their own licences.
Most importantly, **Apple's GPTK is redistributable for non-commercial
use only**, which means D4Mac itself can be freely distributed for
download but **may not be sold** while GPTK is bundled. See
[`THIRD_PARTY_LICENSES.md`](./THIRD_PARTY_LICENSES.md) for every
component and its terms.

## Not affiliated

D4Mac is a community project. Not affiliated with, endorsed by, or
sponsored by Blizzard Entertainment, Apple Inc., or CodeWeavers Inc.
"Diablo" and "Battle.net" are trademarks of Blizzard Entertainment.
