import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var bottle: BottleManager

    @State private var showInstallerPicker = false
    @State private var showError = false

    private static let blizzardWinInstallerURL = URL(
        string: "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP"
    )!

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.appBgTop, .appBgBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.bnetBlue.opacity(0.18), Color.bnetBlue.opacity(0)],
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
                Spacer(minLength: 0)
                primaryAction
                if bottle.phase != .idle { phaseBanner }
                Spacer(minLength: 0)
                BeerTipView()
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
            allowedContentTypes: [UTType(filenameExtension: "exe") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleInstallerPick(result)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("D4Mac")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .bnetBlue],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text("Battle.net on Apple Silicon")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.appSubhead)
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
                if let p = bottle.installProgress, bottle.phase == .runningInstaller {
                    ProgressView(value: p.fraction)
                        .tint(.bnetBlueLight)
                        .padding(.top, 4)
                    Text(progressLine(p))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Color.appCaption)
                }
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

    // MARK: - Footer

    private var footer: some View {
        HStack {
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

    /// "67% · 1.2 GB / 1.8 GB · 8.3 MB/s" — bytes/speed dropped when unknown.
    private func progressLine(_ p: BottleManager.InstallProgress) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useGB, .useMB]
        bcf.countStyle = .file
        var parts = ["\(Int((p.fraction * 100).rounded()))%"]
        if p.bytesTotal > 0 {
            parts.append("\(bcf.string(fromByteCount: p.bytesDone)) / \(bcf.string(fromByteCount: p.bytesTotal))")
        }
        if p.bytesPerSec > 0 {
            parts.append("\(bcf.string(fromByteCount: Int64(p.bytesPerSec)))/s")
        }
        return parts.joined(separator: " · ")
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
