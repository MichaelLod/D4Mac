import Darwin
import Foundation
import os.log

/// Per-launch idempotent setup that redirects D3DMetal's shader bytecode cache
/// out of `/var/folders/.../C/d3dm/` into `~/Library/Application Support/D4Mac/d3dm-cache/`.
///
/// Why: macOS rate-limits per-app file-backed-memory dirtying on the
/// `_CS_DARWIN_USER_CACHE_DIR` namespace. D3DMetal mmaps multi-hundred-MB
/// cache files (`stage_cache.bin`, `bytecode_cache.bin`) and re-dirties pages
/// aggressively during play — measured 34 GB dirtied in 17 min in a single
/// session. Once the rolling daily quota is blown the kernel injects delays
/// into write syscalls, the render thread blocks, the app beachballs.
/// Application Support sits outside that throttled namespace and also
/// survives `/var/folders` auto-cleanup on macOS upgrades and low-disk events.
enum ShaderCacheRedirect {
    private static let log = Logger(subsystem: "com.d4mac.app", category: "shader-cache")
    private static let exeName = "Diablo IV.exe"

    /// Ensure the symlink is in place. Safe to call on every launch.
    /// Failures are logged and swallowed — this is a perf optimisation,
    /// not a correctness requirement; D4 will run (with the old beachball
    /// risk) if this fails.
    static func setup(supportRoot: URL) {
        do {
            let original = try originalCachePath()
            let target = supportRoot
                .appendingPathComponent("d3dm-cache", isDirectory: true)
                .appendingPathComponent(exeName, isDirectory: true)

            let fm = FileManager.default
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            try fm.createDirectory(
                at: original.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            switch sourceState(at: original.path, expectedTarget: target.path) {
            case .alreadyCorrect:
                return
            case .symlinkToWrongTarget, .danglingSymlink, .realDirEmpty, .doesNotExist:
                if fm.fileExists(atPath: original.path) || isSymlink(original.path) {
                    try fm.removeItem(at: original)
                }
                try fm.createSymbolicLink(at: original, withDestinationURL: target)
                log.info("symlinked \(original.path, privacy: .public) → \(target.path, privacy: .public)")
            case .realDirWithContent:
                if fm.fileExists(atPath: target.path) && hasContents(target.path) {
                    try fm.removeItem(at: original)
                    log.info("dropped duplicate source dir; keeping target \(target.path, privacy: .public)")
                } else {
                    if fm.fileExists(atPath: target.path) {
                        try fm.removeItem(at: target)
                    }
                    try fm.moveItem(at: original, to: target)
                    log.info("migrated \(original.path, privacy: .public) → \(target.path, privacy: .public)")
                }
                try fm.createSymbolicLink(at: original, withDestinationURL: target)
            }

            excludeFromTimeMachine(target.deletingLastPathComponent())
        } catch {
            log.error("redirect failed: \(error.localizedDescription, privacy: .public) — using default cache path")
        }
    }

    private enum SourceState {
        case alreadyCorrect
        case symlinkToWrongTarget
        case danglingSymlink
        case realDirEmpty
        case realDirWithContent
        case doesNotExist
    }

    private static func sourceState(at path: String, expectedTarget: String) -> SourceState {
        let fm = FileManager.default
        if let dest = try? fm.destinationOfSymbolicLink(atPath: path) {
            let resolvedDest = (dest as NSString).standardizingPath
            let resolvedTarget = (expectedTarget as NSString).standardizingPath
            if resolvedDest == resolvedTarget { return .alreadyCorrect }
            return fm.fileExists(atPath: resolvedDest) ? .symlinkToWrongTarget : .danglingSymlink
        }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return .doesNotExist
        }
        return hasContents(path) ? .realDirWithContent : .realDirEmpty
    }

    private static func isSymlink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    private static func hasContents(_ path: String) -> Bool {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return !entries.isEmpty
    }

    private static func originalCachePath() throws -> URL {
        let needed = confstr(_CS_DARWIN_USER_CACHE_DIR, nil, 0)
        guard needed > 0 else { throw RedirectError.confstrFailed(errno: errno) }
        var buf = [CChar](repeating: 0, count: needed)
        let written = confstr(_CS_DARWIN_USER_CACHE_DIR, &buf, needed)
        guard written > 0, written <= needed else { throw RedirectError.confstrFailed(errno: errno) }
        let cacheRoot = buf.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        return URL(fileURLWithPath: cacheRoot)
            .appendingPathComponent("d3dm", isDirectory: true)
            .appendingPathComponent(exeName, isDirectory: true)
    }

    private static func excludeFromTimeMachine(_ url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["addexclusion", url.path]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // best effort
        }
    }

    enum RedirectError: Error, LocalizedError {
        case confstrFailed(errno: Int32)
        var errorDescription: String? {
            switch self {
            case .confstrFailed(let e):
                return "confstr(_CS_DARWIN_USER_CACHE_DIR) failed (errno \(e))"
            }
        }
    }
}
