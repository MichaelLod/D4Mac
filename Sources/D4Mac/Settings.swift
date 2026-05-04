import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bottle: BottleManager
    @AppStorage("metalHUD") private var metalHUD = false
    @AppStorage("vendorSpoof") private var vendorSpoof = true
    @AppStorage("syncStyle") private var syncStyle: SyncStyle = .none
    /// When enabled, the d4-watchdog thread inside Wine will SIGKILL the
    /// process after a confirmed 10 s freeze and D4Mac will auto-relaunch it.
    @AppStorage("watchdogAutokill") private var watchdogAutokill = false
    @State private var showMovePicker = false
    @State private var showImport = false

    // Order = display order in the segmented picker. `none` is first and the
    // default: on macOS 26 / Apple Silicon, esync/msync spin-wait pegs a CPU
    // core and throttles Battle.net's downloader to a few KB/s (and can freeze
    // gameplay). Read by WineProcess.environment in BNetLauncher.swift.
    enum SyncStyle: String, CaseIterable, Identifiable {
        case none, esync, msync
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none:  "None (recommended)"
            case .esync: "ESync"
            case .msync: "MSync"
            }
        }
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            advancedTab
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
        .fileImporter(
            isPresented: $showMovePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let dest = urls.first else { return }
            let alert = NSAlert()
            alert.messageText = "Move all D4Mac data?"
            alert.informativeText = "Everything (bottle, installed games, shader cache) moves to \(dest.path)/D4Mac. Battle.net will be closed first. On another drive this copies all data — with games installed it can take a while."
            alert.addButton(withTitle: "Move")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                Task { await bottle.moveSupportDir(to: dest) }
            }
        }
        .sheet(isPresented: $showImport) {
            ImportInstallView().environmentObject(bottle)
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Show Metal performance HUD", isOn: $metalHUD)
                Toggle("Spoof GPU as Apple (recommended for D4)", isOn: $vendorSpoof)
                Toggle("Auto-recover from freezes (experimental)", isOn: $watchdogAutokill)
                if watchdogAutokill {
                    Text("When a freeze lasts 10 s, the game process is killed and restarted automatically. Cloud saves are unaffected. Disable if you see false positives during heavy loading screens.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Performance")
            } footer: {
                Text("Applied the next time you launch Battle.net.")
            }
            Section("Wine sync primitive") {
                Picker("Synchronisation", selection: $syncStyle) {
                    ForEach(SyncStyle.allCases) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.segmented)
                Text("Keep this on None on macOS 26 / Apple Silicon. ESync/MSync spin-wait on the CPU, which throttles Battle.net downloads to a crawl and can freeze the game. Takes effect the next time you launch Battle.net.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var advancedTab: some View {
        Form {
            Section("Diablo IV game data") {
                LabeledContent("Already downloaded elsewhere?") {
                    Button("Import existing install…") { showImport = true }
                }
                Text("Reuse a Diablo IV download from CrossOver, Porting Kit, Whisky or GPTK instead of re-downloading ~140 GB.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Bottle") {
                LabeledContent("Location") {
                    Text(bottle.bottleRoot.resolvingSymlinksInPath().path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.open(bottle.bottleRoot.resolvingSymlinksInPath())
                }
                LabeledContent("Need the space elsewhere?") {
                    Button("Move bottle…") { showMovePicker = true }
                        .disabled(bottle.isBusy)
                }
                Text("Moves all D4Mac data (bottle, games, shader cache) to a folder you pick — e.g. an external SSD — and links it back invisibly. Games keep working; nothing to reinstall.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Battle.net stuck on “Update — Queued”?") {
                    Button("Reset launcher state") {
                        Task { await bottle.resetLauncherState() }
                    }
                    .disabled(bottle.isBusy)
                }
                Text("Clears the Blizzard Agent's cached state so the launcher re-scans your games. Non-destructive: keeps your login and all game files. Use after a freeze or force-quit leaves Battle.net confused.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reset bottle…", role: .destructive) {
                    let alert = NSAlert()
                    alert.messageText = "Reset bottle?"
                    alert.informativeText = "This deletes Battle.net and any Blizzard games installed inside the bottle. Game files outside the bottle (e.g. shared user data) are untouched."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Reset")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        try? bottle.nukeBottle()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("D4Mac is a free, non-commercial Battle.net launcher for Apple Silicon, built on Wine 11.0 and Apple's Game Porting Toolkit 3.0.")
                .font(.callout)
            Divider()
            Text("Bundled software credits & licenses")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                creditLine("Apple D3DMetal & libd3dshared", "Apple GPTK License (non-commercial redistribution)")
                creditLine("Wine 11.0", "LGPL 2.1")
                creditLine("MoltenVK", "Apache 2.0")
                creditLine("Microsoft VC++ Redistributable", "MS redistributable terms")
            }
            .font(.callout)
            Spacer()
            Button("Open Apple GPTK License…") {
                if let url = Bundle.main.url(forResource: "Apple-GPTK-License", withExtension: "pdf") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditLine(_ name: String, _ license: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).fontWeight(.medium)
            Spacer(minLength: 8)
            Text(license).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BottleManager())
        .frame(width: 460, height: 340)
}
