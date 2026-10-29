import Foundation

/// Fetches Blizzard's Battle.net-Setup.exe, so a first install is one click
/// instead of "download in the browser, then find the file in a picker".
enum InstallerDownload {
    /// Blizzard's "current Windows Battle.net installer" link. It redirects to
    /// downloader.battle.net/download/installer/win/<version>/Battle.net-Setup.exe.
    static let sourceURL = URL(
        string: "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP"
    )!

    /// `~/Library/Caches/<bundle id>/Battle.net-Setup.exe`. Kept free of
    /// spaces: Setup hands its own path to the second stage it respawns.
    static var destination: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.d4mac.app", isDirectory: true)
            .appendingPathComponent("Battle.net-Setup.exe")
    }

    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// The installer is ~5 MB today; anything far outside that is an error page
    /// or something that isn't Setup.
    static let sizeRange: ClosedRange<Int64> = 1_000_000...200_000_000

    /// Download to `destination` (replacing any earlier copy) and return it.
    /// `progress` gets the fraction done, or nil while the size is unknown.
    static func download(progress: @escaping @MainActor @Sendable (Double?) -> Void) async throws -> URL {
        // Ephemeral: no on-disk URL cache, so a cached redirect can never hand
        // out an older installer version.
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let (bytes, response) = try await session.bytes(from: sourceURL)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        try checkResponse(status: status, finalURL: response.url)
        let total = response.expectedContentLength

        let dest = destination
        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        let partial = dest.deletingLastPathComponent().appendingPathComponent("Battle.net-Setup.exe.part")
        fm.createFile(atPath: partial.path, contents: nil)
        let out = try FileHandle(forWritingTo: partial)
        defer { try? out.close() }

        var header = Data()
        var chunk = Data()
        var written: Int64 = 0
        chunk.reserveCapacity(1 << 16)
        await progress(total > 0 ? 0 : nil)
        for try await byte in bytes {
            chunk.append(byte)
            guard chunk.count == 1 << 16 else { continue }
            if header.isEmpty { header = chunk.prefix(2) }
            try out.write(contentsOf: chunk)
            written += Int64(chunk.count)
            chunk.removeAll(keepingCapacity: true)
            guard written <= sizeRange.upperBound else { throw Failure("The download is far larger than Battle.net Setup.") }
            await progress(total > 0 ? min(Double(written) / Double(total), 1) : nil)
        }
        if header.isEmpty { header = chunk.prefix(2) }
        try out.write(contentsOf: chunk)
        written += Int64(chunk.count)
        try out.close()

        guard looksLikeInstaller(header: header, size: written) else {
            try? fm.removeItem(at: partial)
            throw Failure("Blizzard's server didn't send a Windows installer.")
        }
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: partial, to: dest)
        await progress(1)
        return dest
    }

    /// We run what we download, so it has to come from Blizzard over HTTPS —
    /// checked on the final URL, after redirects.
    static func checkResponse(status: Int, finalURL: URL?) throws {
        guard let url = finalURL, url.scheme == "https", let host = url.host?.lowercased(),
              ["battle.net", "blizzard.com"].contains(where: { host == $0 || host.hasSuffix("." + $0) })
        else {
            throw Failure("The download was redirected to \(finalURL?.host ?? "an unknown server"), which isn't a Blizzard server.")
        }
        guard status == 200 else {
            throw Failure("Blizzard's download server answered with HTTP \(status).")
        }
    }

    /// A Windows executable starts with "MZ".
    static func looksLikeInstaller(header: Data, size: Int64) -> Bool {
        header.starts(with: [0x4D, 0x5A]) && sizeRange.contains(size)
    }
}
