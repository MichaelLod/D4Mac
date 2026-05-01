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
*"distribute the Apple Software solely for non-commercial purposes."*
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

**Files in bundle**: none — D4Mac symlinks the macOS-bundled copies of
these fonts at first launch.

`/System/Library/Fonts/Supplemental/{Arial, Times New Roman, Courier
New, Georgia, Verdana, Trebuchet MS, Tahoma, Comic Sans MS, Impact,
Webdings, Wingdings}.ttf` are licensed by Apple for use on macOS via
their own agreement with Microsoft. We create symbolic links from these
into the Wine bottle's `c:\windows\Fonts\` so Windows apps find them by
expected filename. **No font files are copied or distributed by D4Mac.**

If a future macOS removes these fonts, D4Mac will silently skip the ones
not present. Users can run `winetricks corefonts` inside the bottle as a
fallback (downloads from the original SourceForge mirror).

## DXMT (optional)

If a future build of D4Mac includes [3Shain/dxmt](https://github.com/3Shain/dxmt)
for D3D11 games (currently we use Apple's GPTK D3D11 forwarder
instead), DXMT is licensed under MIT (versions through 0.80) and LGPL
(after 0.80). DXMT is not bundled in the current build.
