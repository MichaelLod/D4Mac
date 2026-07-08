import Foundation
import os.log

/// Wraps a `wine` subprocess invocation with the env vars the D3DMetal stack
/// needs. Mirrors `launch-d4-direct.sh` in the parent project.
///
/// `extraEnv` overrides anything in the default env. Used to add the BNet-
/// specific knobs (`ROSETTA_ADVERTISE_AVX`, `DOTNET_EnableWriteXorExecute`)
/// that CrossOver's Perl `bin/wine` wrapper sets when launching BNet.
struct WineProcess {
    let wine: URL
    let prefix: URL
    let externalLibDir: URL
    let args: [String]
    var extraEnv: [String: String] = [:]

    private static let log = Logger(subsystem: "com.d4mac.app", category: "wine")

    /// Builds the env dict matching launch-d4-direct.sh.
    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;mscoree=d;mshtml=d"
        env["WINEDEBUG"] = "-all,err+seh"

        // Wine sync primitive, driven by the Settings "Synchronisation" toggle
        // (UserDefaults key "syncStyle"; see SettingsView.SyncStyle). Defaults
        // to "none" — and that default matters: esync/msync spin on userspace
        // sync objects, and on macOS 26 / Apple Silicon under Rosetta that spin
        // pegs a CPU core and starves Battle.net's downloader (~4 KB/s instead
        // of multiple MB/s), besides risking gameplay freezes. With sync off the
        // wineserver arbitrates sync calls — far slower in theory, far more
        // reliable here. Users who want the throughput can opt back into esync.
        switch UserDefaults.standard.string(forKey: "syncStyle") ?? "none" {
        case "msync": env["WINEMSYNC"] = "1"; env["WINEESYNC"] = "1"
        case "esync": env["WINEMSYNC"] = "0"; env["WINEESYNC"] = "1"
        default:      env["WINEMSYNC"] = "0"; env["WINEESYNC"] = "0"  // "none"
        }

        // CrossOver-compatible runtime knobs (CW Wine source patches read these).
        env["CX_ACTIVE_GRAPHICS_BACKEND"] = "d3dmetal"
        env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] =
            externalLibDir.appendingPathComponent("libd3dshared.dylib").path
        env["CX_D3DMETALPATH"] = externalLibDir.path

        let existing = env["DYLD_FALLBACK_LIBRARY_PATH"] ?? "/usr/local/lib:/usr/lib"
        env["DYLD_FALLBACK_LIBRARY_PATH"] = "\(externalLibDir.path):\(existing)"

        // Settings toggles. WineProcess isn't @MainActor, so read UserDefaults
        // directly (that's all @AppStorage is). Defaults here must match the
        // @AppStorage defaults in SettingsView: vendorSpoof=true, metalHUD=false.
        // (The syncStyle picker is wired separately — see the sync PR.)
        let defaults = UserDefaults.standard
        let vendorSpoof = defaults.object(forKey: "vendorSpoof") == nil
            ? true : defaults.bool(forKey: "vendorSpoof")

        // GPU vendor/device spoof so D4 takes the Apple-GPU path.
        if vendorSpoof {
            env["D3DM_VENDOR_ID"] = "0x106b"
            env["D3DM_DEVICE_ID"] = "0x0209"
            env["D3DM_DEVICE_DESCRIPTION"] = "Apple GPU"
        }

        // Apple's built-in Metal performance HUD (FPS / frame-time overlay).
        if defaults.bool(forKey: "metalHUD") {
            env["MTL_HUD_ENABLED"] = "1"
        }

        for (k, v) in extraEnv { env[k] = v }
        return env
    }

    /// Run wine and resolve when the subprocess exits.
    @discardableResult
    func run() async throws -> Int32 {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int32, Error>) in
            let p = Process()
            p.executableURL = wine
            p.arguments = args
            p.environment = environment

            do {
                try p.run()
            } catch {
                cont.resume(throwing: error)
                return
            }

            Self.log.info("wine pid=\(p.processIdentifier) args=\(self.args.joined(separator: " "))")

            p.terminationHandler = { proc in
                Self.log.info("wine exited status=\(proc.terminationStatus)")
                cont.resume(returning: proc.terminationStatus)
            }
        }
    }
}

/// Convenience for launching BNet's main executable.
extension BottleManager {
    /// Spawn Battle.net.exe in the foreground. Returns when BNet exits.
    /// User sees BNet's normal window; D4Mac stays available behind it.
    ///
    /// BNet renders on our bundled LGPL Wine 11.0 with one critical env var:
    /// `WINE_SIMULATE_WRITECOPY=1` enables CW Hack 22996 which is already
    /// compiled into our build (the patch is in the public CrossOver LGPL
    /// source at `dlls/ntdll/unix/{loader,virtual}.c`). Without it, CEF's
    /// renderer hits an `int3` at `libcef.dll+0x16D00E1` because
    /// `VirtualProtect` returns `PAGE_WRITECOPY` (8) where libcef expects
    /// `PAGE_READWRITE` (4). With it, the renderer paints normally.
    ///
    /// The bottle's `drive_c/windows/` is produced by our `wineboot --init`
    /// — no CrossOver content required. See `project_bnet_no_cx_recipe.md`
    /// for the bisect that proved this. `ensureBottle()` handles setup.
    func launchBattleNet() async {
        defer { phase = .idle }
        guard case .ready(let bnetPath) = state else {
            lastError = D4MacError(
                "Battle.net not installed yet.",
                "Run the Battle.net installer first — D4Mac will detect it automatically once it's done."
            ).fullMessage
            return
        }
        do {
            try await ensureBottle()
            phase = .launchingBattleNet

            // Kill any existing BNet/Agent in our prefix first. Otherwise an
            // auto-launched BNet (from end-of-install, or last session's
            // Agent) hangs the prefix with the wrong CEF flags. wineserver -k
            // is scoped to WINEPREFIX so we only affect our bottle.
            await killWineProcesses()

            // First-launch seeding: BNet's config from a fresh install lacks
            // Services.LastLoginTassadar, which deadlocks the renderer on a
            // Select-Your-Region wall. Idempotent — does nothing on subsequent
            // launches once BNet has logged in once.
            seedBNetConfig()

            let proc = WineProcess(
                wine: wineBin,
                prefix: bottleRoot,
                externalLibDir: libExternal,
                args: [
                    bnetPath,
                    "--in-process-gpu",
                    "--use-gl=swiftshader"
                ],
                extraEnv: [
                    "WINE_SIMULATE_WRITECOPY": "1",
                    "WINE_LARGE_ADDRESS_AWARE": "1",
                    "WINE_HEAP_ZERO_MEMORY": "1",
                    "ROSETTA_ADVERTISE_AVX": "1",
                    "DOTNET_EnableWriteXorExecute": "0"
                ]
            )
            let status = try await proc.run()
            if status != 0 {
                lastError = D4MacError(
                    "Battle.net exited unexpectedly (code \(status)).",
                    "Common cause: Battle.net's UI (Chromium) sometimes crashes on first launch under Wine. Try clicking Launch again — it usually works the second time. If it keeps failing, reset the bottle in Settings → Advanced and retry."
                ).fullMessage
            }
            await refresh()
        } catch let err as D4MacError {
            lastError = err.fullMessage
        } catch {
            lastError = error.localizedDescription
        }
    }
}
