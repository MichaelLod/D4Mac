import SwiftUI
import os.log

/// Import an existing Diablo IV install from another Wine wrapper (CrossOver,
/// Porting Kit / Wineskin, Whisky, raw GPTK) into D4Mac's bottle, so Battle.net
/// can adopt it and download only the patch delta instead of the full ~140 GB.
///
/// The heavy lifting is `clonefile(2)`: on APFS, cloning a directory tree is
/// instant and copy-on-write (no extra disk) as long as source and bottle live
/// on the same volume — which they almost always do. Cross-volume falls back to
/// a regular copy.
extension BottleManager {

    /// A Diablo IV game folder found on disk, outside our bottle.
    struct FoundInstall: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let source: String       // human label: "CrossOver", "Porting Kit", …
        let sameVolume: Bool     // true → clone is instant + free
    }

    /// Relative path to the game folder inside a Wine prefix's C: drive.
    private static var gameSubpath: String { "drive_c/Program Files (x86)/Diablo IV" }

    private var importLog: Logger { Logger(subsystem: "com.d4mac.app", category: "import") }

    // MARK: - Validation

    /// A folder is a real Diablo IV install if it has the game exe and Blizzard's
    /// build metadata (`.build.info`), which is what lets Battle.net recognise it.
    func isValidDiabloFolder(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.appendingPathComponent("Diablo IV.exe").path)
            && fm.fileExists(atPath: url.appendingPathComponent(".build.info").path)
    }

    // MARK: - Scan

    /// Search the common Wine-wrapper locations for an existing Diablo IV folder.
    /// Read-only; safe to call anytime.
    func scanForExistingInstalls() -> [FoundInstall] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let bottlePath = bottleRoot.standardizedFileURL.path

        var results: [FoundInstall] = []
        var seen = Set<String>()

        func consider(_ gameFolder: URL, _ source: String) {
            let std = gameFolder.standardizedFileURL
            // Skip the bottle's own copy and anything we've already listed.
            guard std.path != bottlePath, !std.path.hasPrefix(bottlePath + "/") else { return }
            guard isValidDiabloFolder(std), !seen.contains(std.path) else { return }
            seen.insert(std.path)
            results.append(FoundInstall(
                url: std, source: source, sameVolume: sameVolume(std, bottleRoot)))
        }

        // 1. Porting Kit / Kegworks / Wineskin — each game is an `.app` wrapper.
        for appsDir in [home.appendingPathComponent("Applications"),
                        URL(fileURLWithPath: "/Applications")] {
            for app in (try? fm.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil)) ?? []
            where app.pathExtension == "app" {
                consider(app.appendingPathComponent("Contents/SharedSupport/prefix/\(Self.gameSubpath)"),
                         "Porting Kit / Wineskin")
            }
        }

        // 2. Bottle-per-directory wrappers: CrossOver, Whisky, generic GPTK (~/Games).
        let bottleRoots: [(URL, String)] = [
            (home.appendingPathComponent("Library/Application Support/CrossOver/Bottles"), "CrossOver"),
            (home.appendingPathComponent("Library/Containers/com.isaacmarovitz.Whisky/Bottles"), "Whisky"),
            (home.appendingPathComponent("Games"), "Game Porting Toolkit"),
        ]
        for (root, source) in bottleRoots {
            for bottle in (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
                consider(bottle.appendingPathComponent(Self.gameSubpath), source)
            }
        }

        importLog.info("scan found \(results.count) existing Diablo IV install(s)")
        return results
    }

    /// Validate a folder the user picked by hand (it may be the game folder
    /// itself, or a Wine prefix root that contains it).
    func resolvePickedFolder(_ url: URL) -> URL? {
        if isValidDiabloFolder(url) { return url.standardizedFileURL }
        let nested = url.appendingPathComponent(Self.gameSubpath)
        if isValidDiabloFolder(nested) { return nested.standardizedFileURL }
        let nested2 = url.appendingPathComponent("Diablo IV")
        if isValidDiabloFolder(nested2) { return nested2.standardizedFileURL }
        return nil
    }

    // MARK: - Import

    /// Clone (or copy) `src` into the bottle at `C:\Program Files (x86)\Diablo IV`.
    /// Throws on conflict or failure; on success the caller can tell the user to
    /// point Battle.net at `C:\Program Files (x86)` so it verifies + patches.
    func importExistingInstall(from src: URL) async throws {
        defer { phase = .idle }

        try await ensureBottle()

        let destParent = bottleRoot.appendingPathComponent(
            "drive_c/Program Files (x86)", isDirectory: true)
        try FileManager.default.createDirectory(at: destParent, withIntermediateDirectories: true)
        let dest = destParent.appendingPathComponent("Diablo IV", isDirectory: true)

        if FileManager.default.fileExists(atPath: dest.path) {
            throw D4MacError(
                "Diablo IV is already in the bottle.",
                "There's already a C:\\Program Files (x86)\\Diablo IV folder. Remove it first (or use Battle.net's Scan and Repair) if you want to re-import."
            )
        }

        phase = .importingGame
        importLog.info("importing \(src.path) → \(dest.path)")

        // APFS clone first: instant + copy-on-write on the same volume. clonefile
        // recurses into directories, so one call handles the whole tree.
        let cloned = src.withUnsafeFileSystemRepresentation { s in
            dest.withUnsafeFileSystemRepresentation { d in
                clonefile(s, d, 0) == 0
            }
        }

        if !cloned {
            // Different volume (EXDEV) or clone unsupported → plain recursive copy.
            importLog.info("clonefile failed (errno \(errno)); falling back to copy")
            do {
                try FileManager.default.copyItem(at: src, to: dest)
            } catch {
                // Don't leave a half-written folder behind.
                try? FileManager.default.removeItem(at: dest)
                throw D4MacError(
                    "Couldn't import the game files.",
                    "Copying \(src.lastPathComponent) into the bottle failed: \(error.localizedDescription)"
                )
            }
        }

        await refresh()
    }

    // MARK: - Helpers

    /// Same APFS volume? (decides instant clone vs. slow copy.) Compares device ids.
    private func sameVolume(_ a: URL, _ b: URL) -> Bool {
        func dev(_ url: URL) -> dev_t? {
            var st = stat()
            return url.withUnsafeFileSystemRepresentation { p in
                (p != nil && stat(p, &st) == 0) ? st.st_dev : nil
            }
        }
        guard let da = dev(a), let db = dev(b) else { return false }
        return da == db
    }
}

// MARK: - UI

/// Sheet that scans for existing Diablo IV installs and imports the chosen one.
struct ImportInstallView: View {
    @EnvironmentObject var bottle: BottleManager
    @Environment(\.dismiss) private var dismiss

    @State private var found: [BottleManager.FoundInstall] = []
    @State private var scanned = false
    @State private var working = false
    @State private var showFolderPicker = false
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import an existing Diablo IV install")
                .font(.title3).fontWeight(.semibold)
            Text("Already downloaded Diablo IV with CrossOver, Porting Kit, Whisky or GPTK? Bring those files into D4Mac's bottle and Battle.net will only download the patch — not the whole ~140 GB.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if done {
                successView
            } else if working {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(bottle.phase == .importingGame ? "Importing…" : "Working…")
                }
            } else {
                resultsView
            }

            Spacer(minLength: 0)

            HStack {
                Button("Choose folder manually…") { showFolderPicker = true }
                    .disabled(working)
                Spacer()
                Button(done ? "Done" : "Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 380)
        .onAppear { if !scanned { found = bottle.scanForExistingInstalls(); scanned = true } }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let picked = urls.first {
                if let game = bottle.resolvePickedFolder(picked) {
                    startImport(from: game)
                } else {
                    bottle.lastError = D4MacError(
                        "That folder isn't a Diablo IV install.",
                        "Pick the folder that contains \"Diablo IV.exe\" (or the Wine prefix above it)."
                    ).fullMessage
                }
            }
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if found.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("No existing installs found automatically.", systemImage: "magnifyingglass")
                    .font(.callout)
                Text("Use “Choose folder manually…” to point at your old install.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(found) { install in
                        installRow(install)
                    }
                }
            }
        }
    }

    private func installRow(_ install: BottleManager.FoundInstall) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(install.source).fontWeight(.medium)
                    if install.sameVolume {
                        Text("instant").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Color.bnetBlue.opacity(0.2), in: Capsule())
                    }
                }
                Text(install.url.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button("Import") { startImport(from: install.url) }
                .disabled(working)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }

    private var successView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Game files imported.", systemImage: "checkmark.circle.fill")
                .font(.callout).fontWeight(.medium)
                .foregroundStyle(.green)
            Text("Now open Battle.net — it should detect Diablo IV automatically and offer just the patch. If it doesn't, click Diablo IV → Install and point it at **C:\\Program Files (x86)**.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func startImport(from url: URL) {
        working = true
        Task {
            do {
                try await bottle.importExistingInstall(from: url)
                done = true
            } catch let err as D4MacError {
                bottle.lastError = err.fullMessage
            } catch {
                bottle.lastError = error.localizedDescription
            }
            working = false
        }
    }
}
