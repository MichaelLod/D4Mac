# D4Mac

> A free, open-source **Battle.net launcher** for Apple Silicon. Wraps a
> self-contained Wine 11.0 + Apple Game Porting Toolkit 3.0 runtime in a
> small native macOS app.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/arch-Apple%20Silicon-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

<p align="center">
  <a href="https://d4mac.app">
    <img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-148eff?style=for-the-badge&logo=stripe&logoColor=white" alt="Buy me a coffee" />
  </a>
</p>

---

## What it does

- Drop-in Battle.net launcher — run BNet + Blizzard games (Diablo IV first,
  others on a try-at-your-own-risk basis) on Mac
- Self-contained `.app` bundle: Wine 11.0 + Apple D3DMetal 3.0 +
  libd3dshared + GPTK PE forwarders, plus the MSVC runtimes BNet's CEF
  needs
- Zero CrossOver licence required — uses Apple's GPTK 3.0 binaries
  directly under Apple's free non-commercial redistribution clause
- Symlinks macOS-bundled MS Core Fonts (Arial, Times, Verdana, …) into
  the bottle so Windows apps render text correctly with no downloads
- Suppresses Wine's debugger crash dialog so end users don't see internals
- Resets cleanly via Settings → Advanced → Reset bottle

## Status

**MVP.** Diablo IV verified launching past `[Prism] Sync interval is 1`
(the post-Sync crash that historically blocked self-built Wine + D3DMetal
builds is fixed by using GPTK's `apple_gptk` PE binaries with
`lib/wine/x86_64-unix/d3d12.so → libd3dshared.dylib` symlinks).

Other Blizzard games (WoW, Overwatch 2, Hearthstone, Heroes of the Storm)
should work since BNet itself runs, but each needs to be empirically
tested before claiming support.

## Quick start (run a prebuilt build)

When releases land on GitHub, downloading the `.app` and dragging it to
`/Applications` will be all that's needed. Until then, build from source.

## Build from source

```bash
git clone https://github.com/MichaelLod/D4Mac.git
cd D4Mac

# 1) fetch Microsoft VC++ redistributables (~40 MB, not in git)
./Prereqs/fetch.sh

# 2) stage the Wine + GPTK runtime (one-time)
#    — see "Wine runtime" section below for what to put in ../wine-cx26.1
#    — by default build.sh expects it at ../wine-cx26.1/

# 3) assemble the .app
./build.sh                    # debug build, ~1.6 GB .app
./build.sh --release          # optimised build
./build.sh --release --notarize  # signed + notarized via your Apple ID
                                  # requires APPLE_DEV_ID + APPLE_NOTARY_PROFILE
                                  # env vars

open build/D4Mac.app
```

## How it works

```
D4Mac.app/Contents/
├─ MacOS/D4Mac                    SwiftUI launcher binary (arm64)
├─ Resources/
│  ├─ Apple-GPTK-License.pdf      Apple's redistribution license
│  └─ Prereqs/
│     ├─ vc_redist.x86.exe        bundled MS C++ runtime, x86
│     └─ vc_redist.x64.exe        same, x64
└─ SharedSupport/Wine/            self-contained runtime
   ├─ bin/{wine,wineserver,…}     built from CrossOver 26.1 LGPL source
   ├─ lib/external/
   │  ├─ D3DMetal.framework/      Apple GPTK 3.0
   │  └─ libd3dshared.dylib       Apple GPTK 3.0 unix-side dispatch
   ├─ lib/wine/x86_64-windows/
   │  ├─ d3d12.dll, dxgi.dll      Apple GPTK PE forwarders → __wine_unix_call
   │  └─ d3d11.dll, atidxx64.dll, nvapi64.dll, nvngx.dll
   └─ lib/wine/x86_64-unix/
      ├─ d3d12.so → ../external/libd3dshared.dylib   (symlink)
      └─ dxgi.so / d3d11.so / winemetal.so → libd3dshared.dylib
```

User's bottle (BNet install + game data) lives at
`~/Library/Application Support/D4Mac/Bottle/` so the `.app` stays
read-only and code-signed. Resetting the bottle from Settings doesn't
touch the app.

## Wine runtime

D4Mac depends on a Wine 11.0 build with CrossOver's LGPL patches. Until a
prebuilt tarball is published as a GitHub Release artifact, you need to
build it yourself from CrossOver's LGPL source release:

1. Download `crossover-sources-26.1.0.tar.gz` from
   [media.codeweavers.com/pub/crossover/source/](https://media.codeweavers.com/pub/crossover/source/)
2. Build Wine 64-bit using GPTK's `clang` toolchain (Homebrew
   `game-porting-toolkit-compiler`)
3. Stage Apple GPTK 3.0 binaries (`D3DMetal.framework`, `libd3dshared.dylib`,
   `apple_gptk/wine/x86_64-windows/d3d12.dll` etc.) inside `lib/external/`
   and `lib/wine/x86_64-windows/`
4. Symlink `lib/wine/x86_64-unix/d3d12.so → ../external/libd3dshared.dylib`
   (and the same for `dxgi.so`, `d3d11.so`, `winemetal.so`)

We aim to publish a prebuilt runtime tarball alongside D4Mac releases so
casual users can skip the Wine compile.

## Why CrossOver charges $74 and we don't

CrossOver has a private Apple commercial-licence agreement for D3DMetal.
Apple's *public* GPTK binaries are licensed for free non-commercial
redistribution only — that clause is exactly what Whisky, Mythic,
Bourbon, Sikarugir, and D4Mac all use to ship as free downloads. We
**cannot** charge for D4Mac without breaking Apple's GPTK EULA.

## License

D4Mac (the launcher source) is **MIT** — see [LICENSE](LICENSE).

The `.app` bundle ships several pieces of third-party software with
their own licences — see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md):

| Component | Licence |
|---|---|
| D4Mac launcher (this repo) | MIT |
| Wine 11.0 | LGPL 2.1 |
| Apple D3DMetal & libd3dshared | Apple GPTK Licence (free non-commercial) |
| Microsoft VC++ Redistributable | MS DirectX SDK redistributable |
| MS Core Fonts For The Web | symlinks to macOS's pre-licensed copy |
| MoltenVK | Apache 2.0 |

## Contributing

Issues + PRs welcome. The launcher Swift code is small (~1,000 LoC
across six files); the hard work sits in the Wine runtime build, which
the README's "Wine runtime" section walks through.

## Acknowledgements

- **CodeWeavers** for shipping CrossOver's LGPL source (Wine, D3DMetal
  Wine-side patches) — without their open-source contribution this would
  not be feasible
- **Apple** for the Game Porting Toolkit and free non-commercial
  redistribution clause
- **3Shain** for [DXMT](https://github.com/3Shain/dxmt)
- **Whisky / Mythic / Bourbon / Sikarugir** for blazing the trail of
  free Mac Wine launchers
