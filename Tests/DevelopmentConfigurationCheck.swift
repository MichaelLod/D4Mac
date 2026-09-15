import Foundation

@main
struct DevelopmentConfigurationCheck {
    static func main() {
        for (id, directory, development) in [
            ("com.d4mac.app", "D4Mac", false),
            ("com.d4mac.app.dev.gptk3", "D4Mac Development GPTK3", true),
            ("com.d4mac.app.dev.gptk4", "D4Mac Development GPTK4", true)
        ] {
            precondition(DevelopmentConfiguration.supportDirectoryName(bundleIdentifier: id) == directory)
            precondition(DevelopmentConfiguration.isDevelopment(bundleIdentifier: id) == development)
        }
        precondition(!DevelopmentConfiguration.isDevelopment(bundleIdentifier: nil))
        print("Development identities and bottle paths are distinct; production defaults preserved")
    }
}
