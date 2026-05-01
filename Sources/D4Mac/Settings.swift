import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bottle: BottleManager
    @AppStorage("metalHUD") private var metalHUD = false
    @AppStorage("vendorSpoof") private var vendorSpoof = true
    @AppStorage("syncStyle") private var syncStyle: SyncStyle = .msync

    enum SyncStyle: String, CaseIterable, Identifiable {
        case msync, esync, none
        var id: String { rawValue }
        var label: String {
            switch self {
            case .msync: "MSync (recommended)"
            case .esync: "ESync"
            case .none:  "None"
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
    }

    private var generalTab: some View {
        Form {
            Section("Performance") {
                Toggle("Show Metal performance HUD", isOn: $metalHUD)
                Toggle("Spoof GPU as Apple (recommended for D4)", isOn: $vendorSpoof)
            }
            Section("Wine sync primitive") {
                Picker("Synchronisation", selection: $syncStyle) {
                    ForEach(SyncStyle.allCases) { s in Text(s.label).tag(s) }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    private var advancedTab: some View {
        Form {
            Section("Bottle") {
                LabeledContent("Location") {
                    Text(bottle.bottleRoot.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.open(bottle.bottleRoot)
                }
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
