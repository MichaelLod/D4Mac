import Foundation
import os.log

/// Wraps a `wine` subprocess invocation with the env vars the D3DMetal stack
/// needs. Mirrors `launch-d4-direct.sh` in the parent project.
struct WineProcess {
    let wine: URL
    let prefix: URL
    let externalLibDir: URL
    let args: [String]

    private static let log = Logger(subsystem: "com.d4mac.app", category: "wine")

    /// Builds the env dict matching launch-d4-direct.sh.
    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d;mscoree=d;mshtml=d"
        env["WINEDEBUG"] = "-all,err+seh"
        env["WINEMSYNC"] = "1"
        env["WINEESYNC"] = "1"

        // CrossOver-compatible runtime knobs (CW Wine source patches read these).
        env["CX_ACTIVE_GRAPHICS_BACKEND"] = "d3dmetal"
        env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] =
            externalLibDir.appendingPathComponent("libd3dshared.dylib").path
        env["CX_D3DMETALPATH"] = externalLibDir.path

        let existing = env["DYLD_FALLBACK_LIBRARY_PATH"] ?? "/usr/local/lib:/usr/lib"
        env["DYLD_FALLBACK_LIBRARY_PATH"] = "\(externalLibDir.path):\(existing)"

        env["D3DM_VENDOR_ID"] = "0x106b"
        env["D3DM_DEVICE_ID"] = "0x0209"
        env["D3DM_DEVICE_DESCRIPTION"] = "Apple GPU"

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
    /// Battle.net's UI is built on Chromium Embedded Framework (CEF). On Wine,
    /// CEF's renderer sandbox crashes with `int3` in libcef because it relies
    /// on Windows-specific NT APIs Wine doesn't fully implement. Passing
    /// `--no-sandbox`, `--in-process-gpu`, and `--use-gl=swiftshader` is the
    /// minimum set that works: swiftshader (CPU rasterizer) routes around
    /// CEF's GPU init pickiness. DXMT provides a real D3D11 backend in
    /// syswow64 which CEF prefers when GLES 3 init fails, but ANGLE-on-DXMT
    /// alone (no `--use-gl` flag) hangs CEF's body load — DXMT v0.72 lacks
    /// a feature ANGLE expects. Keep the swiftshader flag.
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

            let proc = WineProcess(
                wine: wineBin,
                prefix: bottleRoot,
                externalLibDir: libExternal,
                args: [
                    bnetPath,
                    "--in-process-gpu",
                    "--use-gl=swiftshader",
                    "--no-sandbox"
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
