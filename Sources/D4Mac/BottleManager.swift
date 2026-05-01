import Foundation
import os.log

/// Lifecycle manager for the Wine prefix ("bottle") used by D4Mac.
///
/// Bottle lives at `~/Library/Application Support/D4Mac/Bottle/`. The Wine
/// runtime (`wine-cx26.1/`) lives inside the app bundle at
/// `Contents/SharedSupport/Wine/`. Apple's GPTK D3DMetal binaries are inside
/// `wine-cx26.1/lib/external/` — bundled per Apple's redistribution license.
@MainActor
final class BottleManager: ObservableObject {
    enum BottleState: Equatable {
        case unknown
        case missing                    // bottle dir doesn't exist
        case empty                      // bottle exists but BNet not installed
        case ready(bnetPath: String)    // BNet installed at this path
    }

    /// Long-running operations. Drives the inline status banner.
    enum Phase: Equatable {
        case idle
        case preparingPrefix            // wineboot + GPTK deploy
        case installingFonts            // MS Core Fonts via macOS symlinks
        case installingPrereqs          // Microsoft VC++ runtime, etc.
        case runningInstaller           // BNet installer in Wine
        case launchingBattleNet         // Battle.net.exe running

        var label: String {
            switch self {
            case .idle: ""
            case .preparingPrefix:    "Setting up your bottle…"
            case .installingFonts:    "Installing Windows fonts…"
            case .installingPrereqs:  "Installing Windows prerequisites…"
            case .runningInstaller:   "Installer is running"
            case .launchingBattleNet: "Battle.net is running"
            }
        }

        /// Helper text shown under the headline status.
        var detail: String {
            switch self {
            case .idle: ""
            case .preparingPrefix:
                "Initialising Wine and copying graphics drivers. Takes ~30 s on first run."
            case .installingFonts:
                "Linking macOS-bundled Arial / Times / Courier / Verdana / etc. into the Wine prefix so Windows apps render text correctly."
            case .installingPrereqs:
                "Installing Microsoft VC++ runtime so Battle.net's UI can start. Takes ~1 min on first run."
            case .runningInstaller:
                "Look for the Battle.net installer window. Click through its prompts to finish — D4Mac will pick up automatically when it's done."
            case .launchingBattleNet:
                "Battle.net opened in its own window. Log in there and pick a game to play."
            }
        }
    }

    @Published var state: BottleState = .unknown
    @Published var phase: Phase = .idle
    @Published var lastError: String?

    /// Backwards-compat for the simple `disabled` checks.
    var isBusy: Bool { phase != .idle }

    private let log = Logger(subsystem: "com.d4mac.app", category: "bottle")

    // MARK: - Path resolution

    /// `~/Library/Application Support/D4Mac/`
    var supportRoot: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("D4Mac", isDirectory: true)
    }

    /// `~/Library/Application Support/D4Mac/Bottle/`
    var bottleRoot: URL { supportRoot.appendingPathComponent("Bottle", isDirectory: true) }

    /// Wine runtime inside the app bundle.
    var wineRuntime: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/SharedSupport/Wine", isDirectory: true)
    }

    var wineBin: URL { wineRuntime.appendingPathComponent("bin/wine") }
    var wineserverBin: URL { wineRuntime.appendingPathComponent("bin/wineserver") }
    var libExternal: URL { wineRuntime.appendingPathComponent("lib/external") }
    var gptkPEDir: URL { wineRuntime.appendingPathComponent("lib/wine/x86_64-windows") }
    var dxmt32Dir: URL { wineRuntime.appendingPathComponent("lib/external/dxmt/i386-windows") }
    var dxmt64Dir: URL { wineRuntime.appendingPathComponent("lib/external/dxmt/x86_64-windows") }

    /// Path to BNet's main executable inside the bottle, if installed.
    var bnetExe: URL {
        bottleRoot.appendingPathComponent(
            "drive_c/Program Files (x86)/Battle.net/Battle.net.exe",
            isDirectory: false
        )
    }

    var systemDir32: URL {
        bottleRoot.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
    }

    var systemDirWow64: URL {
        bottleRoot.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
    }

    // MARK: - State refresh

    /// Inspect filesystem and update `state`.
    func refresh() async {
        let fm = FileManager.default
        if !fm.fileExists(atPath: bottleRoot.path) {
            state = .missing
        } else if fm.fileExists(atPath: bnetExe.path) {
            state = .ready(bnetPath: bnetExe.path)
        } else {
            state = .empty
        }
        log.info("bottle state: \(String(describing: self.state))")
    }

    // MARK: - Setup

    /// Verify bundled Wine runtime is present and looks correct.
    /// Throws an actionable error if anything's missing.
    private func verifyRuntime() throws {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: wineBin.path) else {
            throw D4MacError(
                "Wine runtime missing.",
                "The Wine binary couldn't be found inside the app bundle. The app may be corrupted — try reinstalling D4Mac."
            )
        }
        guard fm.fileExists(atPath: libExternal.appendingPathComponent("libd3dshared.dylib").path) else {
            throw D4MacError(
                "D3DMetal runtime missing.",
                "Apple's libd3dshared.dylib is missing from the app bundle's SharedSupport/Wine/lib/external/. Reinstall D4Mac."
            )
        }
        guard fm.fileExists(atPath: gptkPEDir.appendingPathComponent("d3d12.dll").path) else {
            throw D4MacError(
                "GPTK D3D12 binary missing.",
                "Apple's d3d12.dll is missing from the bundled Wine. Reinstall D4Mac."
            )
        }
    }

    /// Initialize the Wine prefix (wineboot) and deploy GPTK D3DMetal
    /// binaries into bottle/drive_c/windows/system32. Idempotent.
    func ensureBottle() async throws {
        try verifyRuntime()
        try FileManager.default.createDirectory(at: bottleRoot, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: systemDir32.path) {
            phase = .preparingPrefix
            log.info("first-time wineboot for \(self.bottleRoot.path)")
            // First wine invocation auto-runs wineboot; do an explicit one for clarity.
            let boot = WineProcess(
                wine: wineBin,
                prefix: bottleRoot,
                externalLibDir: libExternal,
                args: ["wineboot", "--init"]
            )
            do {
                _ = try await boot.run()
            } catch {
                throw D4MacError(
                    "Couldn't initialise Wine prefix.",
                    "wineboot failed: \(error.localizedDescription). Try resetting the bottle from Settings → Advanced."
                )
            }

        }

        // Idempotent — applies on every ensureBottle so existing bottles
        // get fixed too if they predate this code.
        try? await disableCrashDialog()
        try await deployGPTKBinaries()
        try await deployDXMTBinaries()
        try installCoreFonts()
        try await installPrerequisites()
    }

    /// Equivalent of `winetricks corefonts` but with zero downloads. macOS
    /// ships all the MS Core Fonts For The Web in `/System/Library/Fonts/
    /// Supplemental/` (Apple licensed them for Office-for-Mac compatibility).
    /// We symlink each one into `bottle/drive_c/windows/Fonts/` with the
    /// Windows-expected filename so apps that load fonts by exact filename
    /// (`arial.ttf`, `times.ttf`, …) find them.
    private func installCoreFonts() throws {
        let marker = bottleRoot.appendingPathComponent(".d4mac-corefonts-installed")
        if FileManager.default.fileExists(atPath: marker.path) { return }

        phase = .installingFonts

        let macFontDir = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental")
        let winFontDir = bottleRoot.appendingPathComponent(
            "drive_c/windows/Fonts", isDirectory: true
        )
        try FileManager.default.createDirectory(at: winFontDir, withIntermediateDirectories: true)

        // [macOS filename : Windows filename] — covers the standard winetricks
        // corefonts set plus a few Windows extras (Tahoma, Wingdings) that
        // Blizzard installers occasionally use.
        let mapping: [(String, String)] = [
            ("Arial.ttf",                       "arial.ttf"),
            ("Arial Bold.ttf",                  "arialbd.ttf"),
            ("Arial Italic.ttf",                "ariali.ttf"),
            ("Arial Bold Italic.ttf",           "arialbi.ttf"),
            ("Arial Black.ttf",                 "ariblk.ttf"),
            ("Comic Sans MS.ttf",               "comic.ttf"),
            ("Comic Sans MS Bold.ttf",          "comicbd.ttf"),
            ("Courier New.ttf",                 "cour.ttf"),
            ("Courier New Bold.ttf",            "courbd.ttf"),
            ("Courier New Italic.ttf",          "couri.ttf"),
            ("Courier New Bold Italic.ttf",     "courbi.ttf"),
            ("Georgia.ttf",                     "georgia.ttf"),
            ("Georgia Bold.ttf",                "georgiab.ttf"),
            ("Georgia Italic.ttf",              "georgiai.ttf"),
            ("Georgia Bold Italic.ttf",         "georgiaz.ttf"),
            ("Impact.ttf",                      "impact.ttf"),
            ("Tahoma.ttf",                      "tahoma.ttf"),
            ("Tahoma Bold.ttf",                 "tahomabd.ttf"),
            ("Times New Roman.ttf",             "times.ttf"),
            ("Times New Roman Bold.ttf",        "timesbd.ttf"),
            ("Times New Roman Italic.ttf",      "timesi.ttf"),
            ("Times New Roman Bold Italic.ttf", "timesbi.ttf"),
            ("Trebuchet MS.ttf",                "trebuc.ttf"),
            ("Trebuchet MS Bold.ttf",           "trebucbd.ttf"),
            ("Trebuchet MS Italic.ttf",         "trebucit.ttf"),
            ("Trebuchet MS Bold Italic.ttf",    "trebucbi.ttf"),
            ("Verdana.ttf",                     "verdana.ttf"),
            ("Verdana Bold.ttf",                "verdanab.ttf"),
            ("Verdana Italic.ttf",              "verdanai.ttf"),
            ("Verdana Bold Italic.ttf",         "verdanaz.ttf"),
            ("Webdings.ttf",                    "webdings.ttf"),
            ("Wingdings.ttf",                   "wingding.ttf"),
        ]

        let fm = FileManager.default
        var linked = 0
        for (macName, winName) in mapping {
            let src = macFontDir.appendingPathComponent(macName)
            let dst = winFontDir.appendingPathComponent(winName)
            guard fm.fileExists(atPath: src.path) else {
                log.debug("font missing on host, skipping: \(macName)")
                continue
            }
            try? fm.removeItem(at: dst)
            do {
                try fm.createSymbolicLink(at: dst, withDestinationURL: src)
                linked += 1
            } catch {
                log.warning("couldn't symlink \(winName): \(error.localizedDescription)")
            }
        }
        log.info("linked \(linked) MS Core Fonts into bottle")
        try? "ok".write(to: marker, atomically: true, encoding: .utf8)
    }

    /// Bundle prereqs the user might need installed before any Blizzard
    /// installer. Currently: Microsoft VC++ 2015-2022 redistributable, both
    /// x86 and x64 — Chromium-based apps (Battle.net's UI is CEF) statically
    /// link against `msvcp140.dll` / `vcruntime140.dll` and crash without
    /// them. Battle.net.exe itself is a 32-bit app so the x86 redist is the
    /// critical one; D4 is 64-bit so it needs x64 too.
    ///
    /// Runs `/passive /norestart` so the user sees a progress bar and the
    /// EULA is auto-accepted. `/quiet` would be invisible under Wine and
    /// indistinguishable from a hang.
    private func installPrerequisites() async throws {
        let candidates = ["vc_redist.x86", "vc_redist.x64"]
        // Marker per architecture so we don't re-run already-installed components.
        for name in candidates {
            guard let url = Bundle.main.url(
                forResource: name, withExtension: "exe", subdirectory: "Prereqs"
            ) else {
                log.warning("\(name).exe not bundled — skipping (some games may crash)")
                continue
            }
            let marker = bottleRoot.appendingPathComponent(".d4mac-\(name)-installed")
            if FileManager.default.fileExists(atPath: marker.path) {
                continue
            }
            phase = .installingPrereqs
            log.info("installing \(name) from \(url.path)")
            let proc = WineProcess(
                wine: wineBin,
                prefix: bottleRoot,
                externalLibDir: libExternal,
                args: [url.path, "/passive", "/norestart"]
            )
            let status = try await proc.run()
            // 0 = success, 1638 = newer version already installed, 3010 = success-needs-reboot
            // Wine doesn't reboot, so we treat 3010 as success too.
            guard status == 0 || status == 1638 || status == 3010 else {
                throw D4MacError(
                    "Couldn't install \(name).",
                    "Microsoft VC++ runtime installer returned exit code \(status). Try resetting the bottle and reinstalling — sometimes the first attempt fails on a fresh prefix."
                )
            }
            try? "ok".write(to: marker, atomically: true, encoding: .utf8)
        }
    }

    /// Suppress Wine's automatic crash dialog (winedbg popup). Must be run in
    /// the prefix once during first-time setup. Idempotent if re-run.
    private func disableCrashDialog() async throws {
        log.info("disabling wine crash dialog in prefix")
        let proc = WineProcess(
            wine: wineBin,
            prefix: bottleRoot,
            externalLibDir: libExternal,
            args: [
                "reg", "add",
                #"HKEY_CURRENT_USER\Software\Wine\WineDbg"#,
                "/v", "ShowCrashDialog",
                "/t", "REG_DWORD",
                "/d", "0",
                "/f"
            ]
        )
        _ = try await proc.run()
    }

    /// Copy/hardlink GPTK PE DLLs into the bottle's system32. Replaces Wine's
    /// reimpl with Apple's GPTK forwarders so D3D12 maps to Metal.
    private func deployGPTKBinaries() async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: systemDir32, withIntermediateDirectories: true)

        for dll in ["d3d12.dll", "dxgi.dll", "d3d11.dll"] {
            let src = gptkPEDir.appendingPathComponent(dll)
            let dst = systemDir32.appendingPathComponent(dll)
            guard fm.fileExists(atPath: src.path) else { continue }
            // back up Wine's reimpl on first deploy
            let bak = systemDir32.appendingPathComponent("\(dll).before-d3dmetal")
            if fm.fileExists(atPath: dst.path) && !fm.fileExists(atPath: bak.path) {
                try? fm.moveItem(at: dst, to: bak)
            }
            try? fm.removeItem(at: dst)
            try fm.copyItem(at: src, to: dst)
        }

        // GPTK deploy convention: also expose d3d12.dll under the d3d12_d3dmetal.dll
        // alias (some titles look it up by that name).
        for (primary, alias) in [
            ("d3d12.dll", "d3d12_d3dmetal.dll"),
            ("dxgi.dll", "dxgi_d3dmetal.dll")
        ] {
            let p = systemDir32.appendingPathComponent(primary)
            let a = systemDir32.appendingPathComponent(alias)
            guard fm.fileExists(atPath: p.path) else { continue }
            try? fm.removeItem(at: a)
            try? fm.linkItem(at: p, to: a)
        }
    }

    /// Replace Wine's stock 32-bit `d3d11`/`d3d10core`/`dxgi`/`winemetal` in
    /// the bottle's syswow64 with DXMT's, giving 32-bit processes (notably
    /// Battle.net's CEF) a real D3D11→Metal backend. D3DMetal's 64-bit
    /// forwarders in system32 stay untouched so D4's D3D12 path is unaffected.
    /// 64-bit `winemetal.dll` in system32 is also swapped to the DXMT version
    /// so it pairs correctly with the DXMT `winemetal.so` bridge that ships
    /// in the runtime (replacing the D3DMetal libd3dshared symlink).
    private func deployDXMTBinaries() async throws {
        let fm = FileManager.default

        guard fm.fileExists(atPath: dxmt32Dir.appendingPathComponent("d3d11.dll").path) else {
            log.info("DXMT not staged in runtime; skipping DXMT deploy")
            return
        }

        try fm.createDirectory(at: systemDirWow64, withIntermediateDirectories: true)

        for dll in ["d3d11.dll", "d3d10core.dll", "dxgi.dll", "winemetal.dll"] {
            let src = dxmt32Dir.appendingPathComponent(dll)
            let dst = systemDirWow64.appendingPathComponent(dll)
            guard fm.fileExists(atPath: src.path) else { continue }
            let bak = systemDirWow64.appendingPathComponent("\(dll).before-dxmt")
            if fm.fileExists(atPath: dst.path) && !fm.fileExists(atPath: bak.path) {
                try? fm.moveItem(at: dst, to: bak)
            }
            try? fm.removeItem(at: dst)
            try fm.copyItem(at: src, to: dst)
        }

        let metalSrc = dxmt64Dir.appendingPathComponent("winemetal.dll")
        if fm.fileExists(atPath: metalSrc.path) {
            let metalDst = systemDir32.appendingPathComponent("winemetal.dll")
            let metalBak = systemDir32.appendingPathComponent("winemetal.dll.before-dxmt")
            if fm.fileExists(atPath: metalDst.path) && !fm.fileExists(atPath: metalBak.path) {
                try? fm.moveItem(at: metalDst, to: metalBak)
            }
            try? fm.removeItem(at: metalDst)
            try fm.copyItem(at: metalSrc, to: metalDst)
        }
    }

    // MARK: - Installer

    /// Run an arbitrary BNet installer .exe inside the bottle. Used for
    /// initial setup. Returns when wine subprocess exits.
    func runInstaller(_ installerURL: URL) async {
        defer { phase = .idle }
        do {
            try await ensureBottle()
            try checkInstallerFile(installerURL)

            phase = .runningInstaller
            log.info("running installer: \(installerURL.path)")

            let proc = WineProcess(
                wine: wineBin,
                prefix: bottleRoot,
                externalLibDir: libExternal,
                args: [installerURL.path]
            )
            let status = try await proc.run()
            if status != 0 {
                throw D4MacError(
                    "Installer exited with code \(status).",
                    "If you cancelled the Battle.net installer, you can ignore this. Otherwise, retry — sometimes the first attempt fails on a fresh prefix."
                )
            }

            // Battle.net's installer auto-launches Battle.net.exe at the end
            // without our CEF flags, which crash-loops the GPU subprocess on
            // Wine. Kill it so the user can click D4Mac's Launch button to
            // get a properly-flagged launch.
            log.info("installer done — killing any auto-launched BNet so D4Mac's Launch can take over")
            await killWineProcesses()
            await refresh()
            if case .empty = state {
                throw D4MacError(
                    "Installer ran but Battle.net wasn't found afterwards.",
                    "The installer may have failed silently. Check that it's the official Battle.net-Setup.exe from blizzard.com."
                )
            }
        } catch let err as D4MacError {
            lastError = err.fullMessage
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func checkInstallerFile(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            throw D4MacError(
                "Installer file not found.",
                "The file you picked has disappeared. Try downloading Battle.net-Setup.exe again."
            )
        }
        guard fm.isReadableFile(atPath: url.path) else {
            throw D4MacError(
                "Can't read installer file.",
                "macOS denied read access to \(url.lastPathComponent). Move it out of a sandboxed folder (Downloads/iCloud) and try again."
            )
        }
        let lower = url.lastPathComponent.lowercased()
        if !lower.hasSuffix(".exe") {
            throw D4MacError(
                "That's not a Windows .exe.",
                "D4Mac runs Windows installers via Wine. Pick Battle.net-Setup.exe — not a .dmg, .pkg, or .zip."
            )
        }
        if !lower.contains("battle") && !lower.contains("setup") {
            // Soft warning — still allow but log
            log.warning("installer name \(url.lastPathComponent) doesn't look like Battle.net — proceeding anyway")
        }
    }

    // MARK: - Reset

    /// Best-effort uninstall — kills any running Wine processes for this prefix
    /// and nukes the bottle directory.
    func nukeBottle() throws {
        Task { await killWineProcesses() }
        try? FileManager.default.removeItem(at: bottleRoot)
        state = .missing
    }

    /// `wineserver -k` for our prefix — terminates all Wine processes
    /// (BNet, Agent, GPU subprocesses, etc.) cleanly without touching other
    /// Wine prefixes on the system.
    func killWineProcesses() async {
        guard FileManager.default.isExecutableFile(atPath: wineserverBin.path) else { return }
        let kill = Process()
        kill.executableURL = wineserverBin
        kill.arguments = ["-k"]
        kill.environment = ["WINEPREFIX": bottleRoot.path]
        try? kill.run()
        // wineserver -k returns when all clients exit; usually <1 s.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            kill.terminationHandler = { _ in cont.resume() }
        }
        // Sometimes a stray process lingers; SIGKILL by name as a backstop.
        let names = ["Battle.net.exe", "Agent.exe", "Battle.net-Setup"]
        for name in names {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            p.arguments = ["-9", "-f", name]
            try? p.run()
            p.waitUntilExit()
        }
    }
}

// MARK: - Errors

struct D4MacError: Error, LocalizedError {
    let title: String
    let detail: String

    init(_ title: String, _ detail: String) {
        self.title = title
        self.detail = detail
    }

    var errorDescription: String? { fullMessage }
    var fullMessage: String { "\(title)\n\n\(detail)" }
}
