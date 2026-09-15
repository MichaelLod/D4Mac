import Foundation

/// Bundle identity keeps local experiments separate from the installed app.
enum DevelopmentConfiguration {
    static var isDevelopment: Bool {
        isDevelopment(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static func isDevelopment(bundleIdentifier: String?) -> Bool {
        ["com.d4mac.app.dev.gptk3", "com.d4mac.app.dev.gptk4"].contains(bundleIdentifier ?? "")
    }

    static func supportDirectoryName(bundleIdentifier: String?) -> String {
        switch bundleIdentifier {
        case "com.d4mac.app.dev.gptk3": return "D4Mac Development GPTK3"
        case "com.d4mac.app.dev.gptk4": return "D4Mac Development GPTK4"
        default: return "D4Mac"
        }
    }

    static var supportDirectoryName: String {
        supportDirectoryName(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static var graphicsVersion: String {
        let url = Bundle.main.bundleURL.appendingPathComponent(
            "Contents/SharedSupport/Wine/lib/external/D3DMetal.framework/Resources/Info.plist"
        )
        guard let data = try? Data(contentsOf: url),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let version = info["CFBundleShortVersionString"] as? String else { return "unknown" }
        return version
    }
}
