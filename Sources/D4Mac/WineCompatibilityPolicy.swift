import Foundation

/// Environment policy for the Wine-side Diablo IV recovery patches bundled
/// with D4Mac.
///
/// The d4-kick/watchdog hooks were introduced to recover from a Rosetta 2
/// deadlock on older Tahoe builds. CodeWeavers confirms that its workaround is
/// no longer needed starting with macOS 26.5. Leaving the hooks armed on newer
/// systems changes Windows wait semantics for no benefit and can destabilise
/// otherwise healthy game sessions.
enum WineCompatibilityPolicy {
    static func recoveryPatchEnvironment(
        operatingSystemVersion version: OperatingSystemVersion,
        watchdogAutokillEnabled: Bool
    ) -> [String: String] {
        var environment: [String: String] = [:]

        if hasRosettaDeadlockFix(version) {
            environment["D4_KICK_DISABLE"] = "1"

            if watchdogAutokillEnabled {
                environment["D4_WATCHDOG_AUTOKILL"] = "1"
            } else {
                environment["D4_WATCHDOG_DISABLE"] = "1"
            }
        } else if watchdogAutokillEnabled {
            environment["D4_WATCHDOG_AUTOKILL"] = "1"
        }

        return environment
    }

    private static func hasRosettaDeadlockFix(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion > 26
            || (version.majorVersion == 26 && version.minorVersion >= 5)
    }
}
