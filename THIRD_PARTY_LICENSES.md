# Third-party licences in D4Mac.app

D4Mac's launcher binary is MIT (see `LICENSE`). The `.app` bundle ships
the following third-party components, each retaining its own licence.

## Apple Game Porting Toolkit 3.0

**Files in bundle**:

- `Contents/SharedSupport/Wine/lib/external/D3DMetal.framework/`
- `Contents/SharedSupport/Wine/lib/external/libd3dshared.dylib`
- `Contents/SharedSupport/Wine/lib/wine/x86_64-windows/d3d12.dll`
- `Contents/SharedSupport/Wine/lib/wine/x86_64-windows/dxgi.dll`
- `Contents/SharedSupport/Wine/lib/wine/x86_64-windows/d3d11.dll`
- `Contents/SharedSupport/Wine/lib/wine/x86_64-windows/atidxx64.dll`
- `Contents/SharedSupport/Wine/lib/wine/x86_64-windows/nvapi64.dll`
- `Contents/SharedSupport/Wine/lib/wine/x86_64-windows/nvngx.dll`

**Licence**: Apple GPTK Licence, redistributable per clause (i)(iii)
_"distribute the Apple Software solely for non-commercial purposes."_
The unmodified `License.pdf` is included in `Contents/Resources/` per
that clause's requirements.

**Source**: [Apple Game Porting Toolkit 3.0 release archive](https://developer.apple.com/games/game-porting-toolkit/)

**Critical**: D4Mac and any fork **may not be sold or bundled into a
commercial product** while these binaries are present. Distributing for
free public download is the only redistribution path Apple's licence
permits.

## Wine 11.0

**Files in bundle**: everything else under `Contents/SharedSupport/Wine/`,
notably:

- `bin/{wine, wineserver, wineloader, …}`
- `lib/wine/x86_64-windows/wined3d.dll` and other Wine PE modules
- `lib/wine/x86_64-unix/{ntdll, kernel32, …}.so`
- `share/wine/wine.inf`

**Licence**: GNU Lesser General Public Licence 2.1 (LGPL-2.1).

**Source**: built from CodeWeavers' CrossOver 26.1 LGPL source release
at [media.codeweavers.com/pub/crossover/source/](https://media.codeweavers.com/pub/crossover/source/),
with no additional patches in our scaffolding (the `dlls/winemetal/` etc.
directories from earlier development were removed from the build —
D4Mac uses Apple's GPTK PE forwarders instead). The complete
corresponding source is available at the upstream URL.

## MoltenVK

**Files in bundle**: `Contents/SharedSupport/Wine/lib/external/libMoltenVK.dylib`

**Licence**: Apache 2.0.

**Source**: [github.com/KhronosGroup/MoltenVK](https://github.com/KhronosGroup/MoltenVK).
Used as a fallback for the vkd3d code path; D3DMetal does not depend on
it but bundling allows games that prefer Vulkan/MoltenVK to run.

## Microsoft Visual C++ 2015-2022 Redistributable

**Files in bundle**:

- `Contents/Resources/Prereqs/vc_redist.x86.exe`
- `Contents/Resources/Prereqs/vc_redist.x64.exe`

**Licence**: Microsoft Visual C++ Redistributable Licence Terms.
Microsoft permits redistribution alongside applications that depend on
it (which BNet's CEF subprocesses do). The full licence is at
[aka.ms/VCRedistLicense](https://aka.ms/VCRedistLicense).

**Source**: official Microsoft installers fetched from `aka.ms/vs/17/release/vc_redist.{x86,x64}.exe`
by `Prereqs/fetch.sh`. Files are unmodified.

## Microsoft Core Fonts For The Web

**Files in bundle (after build)**: `Resources/Fonts/{Arial,Arialbd,
Arialbi,Ariali,AriBlk,AndaleMo,Comic,Comicbd,cour,courbd,courbi,couri,
Georgia,Georgiab,Georgiai,Georgiaz,Impact,Times,Timesbd,Timesbi,Timesi,
trebuc,Trebucbd,trebucbi,trebucit,Verdana,Verdanab,Verdanai,Verdanaz,
Webdings}.TTF/.ttf`

**Not committed to the repo.** Fetched by `Resources/Fonts/fetch.sh`
from the SourceForge Wine corefonts mirror (the original Microsoft
1996 EULA-distributable installers, unmodified). Run `fetch.sh` once
after cloning, or `build.sh` invokes it automatically when fonts are
missing.

**Licence**: Microsoft Core Fonts For The Web EULA (1996, original
distribution). Microsoft discontinued the package in 2002 but never
revoked the EULA on copies already distributed; the SourceForge mirror
preserves them. Redistribution permitted only in the original installer
form, hence the fetch step rather than committing extracted .TTFs.

## CJK fonts — user-supplied (`msyh.ttc`, `simsun.ttc`)

**Files**: `Resources/Fonts/msyh.ttc` (Microsoft YaHei),
`Resources/Fonts/simsun.ttc` (SimSun) — **optional, user-supplied**.

These are Microsoft proprietary CJK fonts and are **not redistributable**
in any form. They are NOT in the repo and NOT fetched by `fetch.sh`.
If you need Chinese rendering, copy them from `C:\Windows\Fonts\` on a
licensed Windows install. Otherwise, the bundled Adobe Source Han Sans
serves as a free CJK fallback for Battle.net.

## Adobe Source Han Sans

**Files in bundle**: `Resources/Fonts/SourceHanSans*.otf`,
`Resources/Fonts/SourceHanSansK*.otf` (Korean),
`Resources/Fonts/SourceHanSansTC*.otf` (Traditional Chinese).

**Licence**: SIL Open Font License 1.1 — see
`Resources/Fonts/LICENSE-source-han-sans.txt`. Free to redistribute.

**Source**: [github.com/adobe-fonts/source-han-sans](https://github.com/adobe-fonts/source-han-sans).
Used as the CJK fallback when Microsoft YaHei / SimSun are not
available in the bottle.

## DXMT v0.72

**Files in bundle**:

- `Contents/SharedSupport/Wine/lib/external/dxmt/i386-windows/{d3d11,d3d10core,dxgi,winemetal}.dll`
- `Contents/SharedSupport/Wine/lib/external/dxmt/x86_64-windows/{d3d11,d3d10core,dxgi,winemetal,nvapi64,nvngx}.dll`
- `Contents/SharedSupport/Wine/lib/external/dxmt/x86_64-unix/winemetal.so`
- The 32-bit DLLs are deployed to `bottle/drive_c/windows/syswow64/` at first
  run, replacing Wine's reimpl with DXMT's D3D11→Metal translator. The
  unix bridge is also installed at `lib/wine/x86_64-unix/winemetal.so`.

**Why bundled**: Battle.net's CEF (Chromium Embedded Framework) is 32-bit
and needs a real D3D11 backend. Apple's GPTK ships only 64-bit D3D11
forwarders, so without DXMT the BNet launcher window fails to render.
With DXMT in syswow64 + D3DMetal in system32, the runtime supports both
D3D11 (BNet) and D3D12 (Diablo IV) simultaneously.

**Licence**: MIT (Copyright 2023 Feifan He). See
`lib/external/dxmt/LICENSE` in the bundle. v0.81+ switched to LGPL; we
ship v0.72 to keep the MIT terms.

**Source**: [github.com/3Shain/dxmt](https://github.com/3Shain/dxmt) at
the v0.72 tag.

## FreeType / GnuTLS x86_64 dependency chain

**Files in bundle**: `Contents/SharedSupport/Wine/lib/external/`

- `libfreetype.6.dylib`, `libpng16.16.dylib`
- `libgnutls.30.dylib`, `libnettle.9.dylib`, `libhogweed.7.dylib`,
  `libgmp.10.dylib`, `libtasn1.6.dylib`, `libp11-kit.0.dylib`,
  `libidn2.0.dylib`, `libunistring.5.dylib`, `libintl.8.dylib`

**Why bundled**: the x86_64 Wine runtime `dlopen()`s these libraries by
leaf name at runtime (FreeType for text rendering, GnuTLS for TLS) and
resolves them out of `lib/external` via `DYLD_FALLBACK_LIBRARY_PATH`.
Without an x86_64 build present, Apple Silicon users with only ARM
Homebrew — or no Homebrew — saw blank text in Battle.net Setup and TLS
failures. Bundling the whole closure removes the Intel-Homebrew dependency.

**Modifications**: unmodified library code. Only Mach-O install names and
inter-library dependency paths were rewritten to `@rpath/<leaf>` (via
`install_name_tool`) so dyld resolves the chain from `lib/external`. No
compiled code is altered.

**Licences** (all free / redistributable; libraries are dynamically loaded,
so the LGPL relinking provision is satisfiable):

| Library                            | Upstream                                                                    | Licence                               |
| ---------------------------------- | --------------------------------------------------------------------------- | ------------------------------------- |
| FreeType (`libfreetype`)           | [freetype.org](https://freetype.org)                                        | FTL or GPL-2.0-or-later               |
| libpng (`libpng16`)                | [libpng.org](http://www.libpng.org/pub/png/libpng.html)                     | PNG Reference Library License v2      |
| GnuTLS (`libgnutls`)               | [gnutls.org](https://www.gnutls.org)                                        | LGPL-2.1-or-later                     |
| Nettle (`libnettle`, `libhogweed`) | [lysator.liu.se/~nisse/nettle](https://www.lysator.liu.se/~nisse/nettle/)   | LGPL-3.0-or-later or GPL-2.0-or-later |
| GMP (`libgmp`)                     | [gmplib.org](https://gmplib.org)                                            | LGPL-3.0-or-later or GPL-2.0-or-later |
| libtasn1 (`libtasn1`)              | [gnu.org/software/libtasn1](https://www.gnu.org/software/libtasn1/)         | LGPL-2.1-or-later                     |
| p11-kit (`libp11-kit`)             | [p11-glue.github.io](https://p11-glue.github.io/p11-glue/p11-kit.html)      | BSD-3-Clause                          |
| libidn2 (`libidn2`)                | [gnu.org/software/libidn](https://www.gnu.org/software/libidn/)             | LGPL-3.0-or-later or GPL-2.0-or-later |
| libunistring (`libunistring`)      | [gnu.org/software/libunistring](https://www.gnu.org/software/libunistring/) | LGPL-3.0-or-later or GPL-2.0-or-later |
| gettext runtime (`libintl`)        | [gnu.org/software/gettext](https://www.gnu.org/software/gettext/)           | LGPL-2.1-or-later                     |

**Source**: prebuilt x86_64 macOS bottles from Homebrew's GHCR registry
(`ghcr.io/homebrew/core/*`), staged by `Prereqs/fetch-wine-libs.py`. The
complete corresponding source for each library is available from its
upstream above and from [github.com/Homebrew/homebrew-core](https://github.com/Homebrew/homebrew-core).
