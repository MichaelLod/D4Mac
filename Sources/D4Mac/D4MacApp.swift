import SwiftUI
import Sparkle

@main
struct D4MacApp: App {
    @StateObject private var bottle = BottleManager()
    private let updaterController: SPUStandardUpdaterController?

    init() {
        if DevelopmentConfiguration.isDevelopment {
            updaterController = nil
        } else {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bottle)
                .frame(minWidth: 520, minHeight: 480)
                .task { await bottle.refresh() }
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                if let updaterController {
                    CheckForUpdatesView(updater: updaterController.updater)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(bottle)
                .frame(width: 460, height: 340)
                .preferredColorScheme(.dark)
                .tint(.bnetBlue)
        }
    }
}

private struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

@MainActor
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
