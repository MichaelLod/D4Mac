import Foundation

/// Rosetta 2 runs the bundled Wine, which is x86_64. A fresh Apple Silicon
/// Mac doesn't have it, and without it every Wine call fails with "Bad CPU
/// type in executable" (issue #18) — so D4Mac checks for it up front and
/// offers to install it.
enum Rosetta {
    /// Whether this Mac can run x86_64 code: spawns the x86_64 slice of
    /// `probe`, which fails with EBADARCH while Rosetta is missing. (Tests
    /// pass an arm64-only binary to get the same failure on a Mac that has it.)
    static func isInstalled(probe: String = "/usr/bin/true") async -> Bool {
        await run("/usr/bin/arch", ["-x86_64", probe]).status == 0
    }

    enum InstallResult: Equatable {
        case installed
        case cancelled              // user dismissed the password prompt
        case failed(String)
    }

    /// Install via `softwareupdate`, behind the standard macOS administrator
    /// password prompt. Runs through osascript rather than NSAppleScript so
    /// the main thread stays free while the prompt and the download are up.
    static func install() async -> InstallResult {
        let script = "do shell script \"/usr/sbin/softwareupdate --install-rosetta --agree-to-license\" with administrator privileges"
        let r = await run("/usr/bin/osascript", ["-e", script])
        return interpret(status: r.status, stderr: r.stderr)
    }

    /// osascript reports a dismissed password prompt as error -128.
    static func interpret(status: Int32, stderr: String) -> InstallResult {
        if status == 0 { return .installed }
        if stderr.contains("(-128)") { return .cancelled }
        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed(message.isEmpty ? "softwareupdate exited with status \(status)." : message)
    }

    private static func run(_ tool: String, _ args: [String]) async -> (status: Int32, stderr: String) {
        await withCheckedContinuation { cont in
            let p = Process()
            let err = Pipe()
            p.executableURL = URL(fileURLWithPath: tool)
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = err
            p.terminationHandler = { proc in
                let data = err.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (proc.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do { try p.run() } catch { cont.resume(returning: (-1, error.localizedDescription)) }
        }
    }
}
