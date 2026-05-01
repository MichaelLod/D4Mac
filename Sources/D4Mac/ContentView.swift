import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bottle: BottleManager
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(ThemeStore.self) private var themes
    let activationStatus: ActivationStatus

    @State private var showInstallerPicker = false
    @State private var showError = false

    private static let blizzardWinInstallerURL = URL(
        string: "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP"
    )!

    var body: some View {
        ZStack {
            themes.current.background.ignoresSafeArea()

            RadialGradient(
                colors: [themes.current.accent.opacity(0.18), themes.current.accent.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            VStack(spacing: 18) {
                Spacer(minLength: 8)
                header
                if !activationStatus.isIdle { activationToast }
                Spacer(minLength: 0)
                primaryAction
                if bottle.phase != .idle { phaseBanner }
                Spacer(minLength: 0)
                skinSection
                footer
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
        }
        .alert("Something went wrong", isPresented: $showError, presenting: bottle.lastError) { _ in
            Button("OK", role: .cancel) { bottle.lastError = nil }
        } message: { msg in
            Text(msg)
        }
        .onChange(of: bottle.lastError) { _, new in
            showError = new != nil
        }
        .fileImporter(
            isPresented: $showInstallerPicker,
            allowedContentTypes: [.application, .item],
            allowsMultipleSelection: false
        ) { result in
            handleInstallerPick(result)
        }
        .animation(.smooth(duration: 0.35), value: themes.current.id)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("D4Mac")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: themes.current.titleGradient,
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text("Battle.net on Apple Silicon")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.appSubhead)
        }
    }

    // MARK: - Activation toast

    @ViewBuilder
    private var activationToast: some View {
        switch activationStatus {
        case .idle:
            EmptyView()
        case .success(let count):
            Label(
                "Activated — \(count) skin\(count == 1 ? "" : "s") unlocked",
                systemImage: "checkmark.seal.fill"
            )
            .foregroundStyle(.green)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        case .error(let message):
            Label("Activation failed: \(message)", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 440)
        }
    }

    // MARK: - Primary action (launcher)

    @ViewBuilder
    private var primaryAction: some View {
        switch bottle.state {
        case .unknown:
            ProgressView().controlSize(.large)
        case .missing, .empty:
            installCard
        case .ready:
            playCard
        }
    }

    private var installCard: some View {
        VStack(spacing: 14) {
            Text("Battle.net not installed")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(Color.appHeadline)
            Text("Pick a Battle.net-Setup.exe to install it into your bottle.")
                .font(.callout)
                .foregroundStyle(Color.appSubhead)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button {
                showInstallerPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 22, weight: .regular))
                    Text("Install Battle.net")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.bnetBlueLight, .bnetBlue, .bnetBlueDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(color: .bnetBlue.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(bottle.isBusy)
            .opacity(bottle.isBusy ? 0.5 : 1)
            .frame(maxWidth: 320)

            Button {
                NSWorkspace.shared.open(Self.blizzardWinInstallerURL)
            } label: {
                Label("Download Battle.net exe from Blizzard", systemImage: "safari")
                    .font(.callout)
                    .foregroundStyle(Color.bnetBlueLight)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .disabled(bottle.isBusy)
        }
    }

    private var playCard: some View {
        VStack(spacing: 12) {
            Button {
                Task { await bottle.launchBattleNet() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                    Text("Launch Battle.net")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.bnetBlueLight, .bnetBlue, .bnetBlueDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .bnetBlue.opacity(0.45), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(bottle.isBusy)
            .opacity(bottle.isBusy ? 0.5 : 1)
            .frame(maxWidth: 360)

            Text("Diablo IV verified · other Blizzard games tested at your own risk")
                .font(.caption)
                .foregroundStyle(Color.appCaption)
        }
    }

    private var phaseBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(.bnetBlueLight)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(bottle.phase.label)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appHeadline)
                Text(bottle.phase.detail)
                    .font(.caption)
                    .foregroundStyle(Color.appSubhead)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bnetBlue.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.bnetBlue.opacity(0.30), lineWidth: 1)
                )
        )
        .frame(maxWidth: 420)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Skin section

    private var skinSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Theme")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSWorkspace.shared.open(Endpoints.skinsPageURL)
                } label: {
                    Label("Get more", systemImage: "sparkles")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(themes.current.accent)
                .help("Browse all skins on d4mac.app")
            }
            HStack(spacing: 12) {
                ForEach(themes.available, id: \.id) { theme in
                    ThemeChip(theme: theme)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(themes.current.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 460)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if entitlements.hasLicense {
                Label(
                    "\(entitlements.ownedSkins.count) skin\(entitlements.ownedSkins.count == 1 ? "" : "s") owned",
                    systemImage: "lock.open.fill"
                )
                .font(.caption2)
                .foregroundStyle(.green.opacity(0.75))
            }
            Spacer()
            Text(versionString)
                .font(.caption2)
                .foregroundStyle(Color.appCaption)
        }
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(v) (\(b))"
    }

    private func handleInstallerPick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            bottle.lastError = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await bottle.runInstaller(url) }
        }
    }
}

// MARK: - Theme chip

struct ThemeChip: View {
    @Environment(ThemeStore.self) private var themes
    let theme: any AppTheme

    var body: some View {
        let isSelected = themes.current.id == theme.id
        let unlocked = themes.canUse(theme)

        Button {
            if unlocked {
                themes.select(theme)
            } else if let entitlement = theme.requiredEntitlement {
                NSWorkspace.shared.open(Endpoints.buyURL(for: entitlement))
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: theme.titleGradient, startPoint: .top, endPoint: .bottom))
                        .frame(width: 38, height: 38)
                    if !unlocked {
                        Circle().fill(.black.opacity(0.55))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.white : .clear, lineWidth: 2.5)
                        .padding(-3)
                )
                .frame(width: 38, height: 38)

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(unlocked ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help(unlocked ? "Use \(theme.displayName)" : "Buy \(theme.displayName) — opens Stripe")
    }
}
