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
        case installingFonts            // copy bundled MS Core Fonts + Source Han Sans
        case installingPrereqs          // Microsoft VC++ runtime, etc.
        case runningInstaller           // BNet installer in Wine
        case launchingBattleNet         // Battle.net.exe running

        var label: String {
            switch self {
            case .idle: ""
            case .preparingPrefix:    "Pouring a fresh bottle…"
            case .installingFonts:    "Teaching it to speak Windows…"
            case .installingPrereqs:  "Stoking the engine…"
            case .runningInstaller:   "Battle.net's moving in"
            case .launchingBattleNet: "Battle.net is live"
            }
        }

        /// Helper text shown under the headline status.
        var detail: String {
            switch self {
            case .idle: ""
            case .preparingPrefix:
                "Wiring up Wine and slipping in the graphics drivers. ~30 s on the first pour."
            case .installingFonts:
                "A little behind-the-scenes prep so the menus look the way they should."
            case .installingPrereqs:
                "Cranking up everything Battle.net needs to open. ~1 min on the first run."
            case .runningInstaller:
                "Look for the installer window — click through its prompts and D4Mac will take over once it's home."
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

    /// Initialize the bottle from scratch using our bundled Wine.
    ///
    /// The chain: `wineboot --init` → corefonts symlinks → vc_redist install
    /// → GPTK D3D12 forwarders for D4. BNet renders fine on this with the
    /// `WINE_SIMULATE_WRITECOPY=1` env var set at launch time (CW Hack 22996,
    /// already compiled into our LGPL Wine source). See
    /// `project_bnet_no_cx_recipe.md` for the verified bisect.
    func ensureBottle() async throws {
        try verifyRuntime()
        try FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)

        let fm = FileManager.default
        let alreadyInitialised = fm.fileExists(atPath: systemDir32.path)

        if !alreadyInitialised {
            phase = .preparingPrefix
            log.info("running wineboot --init → \(self.bottleRoot.path)")
            try await runWineboot()
        }

        try? await disableCrashDialog()
        try await deployGPTKBinaries()
        try installCoreFonts()
        try await installPrerequisites()

        ShaderCacheRedirect.setup(supportRoot: supportRoot)
    }

    /// `wine wineboot --init` against our prefix. Creates drive_c skeleton,
    /// system.reg/user.reg, and the wine fake PE DLLs in system32/syswow64.
    private func runWineboot() async throws {
        let proc = WineProcess(
            wine: wineBin,
            prefix: bottleRoot,
            externalLibDir: libExternal,
            args: ["wineboot", "--init"]
        )
        let status = try await proc.run()
        guard status == 0 else {
            throw D4MacError(
                "wineboot --init failed (exit \(status)).",
                "The bundled Wine couldn't initialise a prefix at \(bottleRoot.path). Try resetting the bottle and retrying."
            )
        }
    }

    /// Copy every font from the bundled `Resources/Fonts/` directory into
    /// `bottle/drive_c/windows/Fonts/`. The bundled set mirrors what CrossOver
    /// ships in their BNet bottle: MS Core Fonts For The Web (Arial, Times,
    /// Verdana, …) under their original Windows filenames, plus Source Han
    /// Sans for CJK rendering. APFS clone-on-write keeps disk overhead minimal.
    private func installCoreFonts() throws {
        let marker = bottleRoot.appendingPathComponent(".d4mac-corefonts-installed")
        if FileManager.default.fileExists(atPath: marker.path) { return }

        phase = .installingFonts

        let bundleFontDir = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/Fonts", isDirectory: true)
        guard FileManager.default.fileExists(atPath: bundleFontDir.path) else {
            log.warning("Resources/Fonts not bundled at \(bundleFontDir.path) — skipping font deploy")
            return
        }

        let winFontDir = bottleRoot.appendingPathComponent(
            "drive_c/windows/Fonts", isDirectory: true
        )
        let fm = FileManager.default
        try fm.createDirectory(at: winFontDir, withIntermediateDirectories: true)

        let bundledFiles = try fm.contentsOfDirectory(at: bundleFontDir, includingPropertiesForKeys: nil)
        var copied = 0
        for src in bundledFiles {
            let dst = winFontDir.appendingPathComponent(src.lastPathComponent)
            try? fm.removeItem(at: dst)
            do {
                try fm.copyItem(at: src, to: dst)
                copied += 1
            } catch {
                log.warning("couldn't copy \(src.lastPathComponent): \(error.localizedDescription)")
            }
        }
        log.info("copied \(copied) bundled fonts into bottle")
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
        // Strict: must look like Battle.net-Setup.exe. Other .exe files in
        // this prefix are unsupported and frequently break the bottle (e.g.
        // installing other game launchers, random Windows apps, etc.).
        if !lower.hasPrefix("battle.net-setup") {
            throw D4MacError(
                "Only Battle.net-Setup.exe is supported.",
                "D4Mac is purpose-built for Battle.net + Diablo IV. Download Battle.net-Setup.exe from blizzard.com and pick that file. Other installers will be rejected."
            )
        }
    }

    // MARK: - BNet config seeding

    /// Seed `Battle.net.config` with the login URLs so a freshly-installed
    /// BNet doesn't get stuck on its "Select your region" wall (where the
    /// renderer paints `resources://icon_error.png` because `LastLoginTassadar`
    /// is empty). Idempotent — only writes if the keys are missing.
    ///
    /// CrossOver bottles already have these values from prior logins; ours
    /// don't, because BNet only writes them after a successful login flow,
    /// and we can't get to login without them.
    func seedBNetConfig() {
        let configURL = bottleRoot.appendingPathComponent(
            "drive_c/users/crossover/AppData/Roaming/Battle.net/Battle.net.config",
            isDirectory: false
        )
        let fm = FileManager.default
        guard fm.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // BNet's per-account block uses a hashed-key name. There's typically
        // exactly one such top-level key — find it by looking for a child
        // dict with a "Services" subdict.
        let accountKey = json.keys.first { key in
            guard let inner = json[key] as? [String: Any] else { return false }
            return inner["Services"] != nil
        }
        guard let accountKey,
              var account = json[accountKey] as? [String: Any],
              var services = account["Services"] as? [String: Any]
        else { return }

        var changed = false
        if services["LastLoginAddress"] == nil {
            services["LastLoginAddress"] = "us.actual.battle.net"
            changed = true
        }
        if services["LastLoginTassadar"] == nil {
            services["LastLoginTassadar"] = "account.battle.net"
            changed = true
        }
        guard changed else { return }

        account["Services"] = services
        json[accountKey] = account
        guard let out = try? JSONSerialization.data(
            withJSONObject: json, options: [.prettyPrinted]
        ) else { return }
        try? out.write(to: configURL)
        log.info("seeded Battle.net.config Services URLs")
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
