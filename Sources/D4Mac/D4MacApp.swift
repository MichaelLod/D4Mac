import SwiftUI

@main
struct D4MacApp: App {
    @StateObject private var bottle = BottleManager()
    @State private var entitlements: EntitlementStore
    @State private var themes: ThemeStore
    @State private var activationStatus: ActivationStatus = .idle

    init() {
        let entitlements = EntitlementStore()
        _entitlements = State(initialValue: entitlements)
        _themes = State(initialValue: ThemeStore(entitlements: entitlements))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(activationStatus: activationStatus)
                .environmentObject(bottle)
                .environment(entitlements)
                .environment(themes)
                .frame(minWidth: 520, minHeight: 480)
                .task { await bottle.refresh() }
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    activationStatus = handleActivation(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(bottle)
                .frame(width: 460, height: 340)
                .preferredColorScheme(.dark)
                .tint(.bnetBlue)
        }
    }

    private func handleActivation(_ url: URL) -> ActivationStatus {
        guard url.scheme == "d4mac",
              url.host == "activate",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = comps.queryItems?.first(where: { $0.name == "token" })?.value
        else {
            return .error("Malformed activation URL")
        }
        do {
            try entitlements.ingest(token)
            themes.reconcile()
            return .success(skinCount: entitlements.ownedSkins.count)
        } catch {
            return .error(String(describing: error))
        }
    }
}

enum ActivationStatus: Equatable {
    case idle
    case success(skinCount: Int)
    case error(String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}
