import Darwin
import Foundation

@main
struct WineCompatibilityPolicyCheck {
    static func main() {
        var failures = 0

        check(
            policy(major: 26, minor: 3),
            equals: [:],
            name: "legacy Tahoe",
            failures: &failures
        )
        check(
            policy(major: 26, minor: 3, autokill: true),
            equals: ["D4_WATCHDOG_AUTOKILL": "1"],
            name: "legacy Tahoe with autokill",
            failures: &failures
        )
        check(
            policy(major: 26, minor: 4),
            equals: [:],
            name: "Tahoe 26.4",
            failures: &failures
        )
        check(
            policy(major: 26, minor: 5),
            equals: [
                "D4_KICK_DISABLE": "1",
                "D4_WATCHDOG_DISABLE": "1",
            ],
            name: "fixed Tahoe",
            failures: &failures
        )
        check(
            policy(major: 26, minor: 5, autokill: true),
            equals: [
                "D4_KICK_DISABLE": "1",
                "D4_WATCHDOG_AUTOKILL": "1",
            ],
            name: "fixed Tahoe with autokill",
            failures: &failures
        )
        check(
            policy(major: 27, minor: 0),
            equals: [
                "D4_KICK_DISABLE": "1",
                "D4_WATCHDOG_DISABLE": "1",
            ],
            name: "future macOS",
            failures: &failures
        )

        guard failures == 0 else { exit(EXIT_FAILURE) }
        print("Wine compatibility policy checks passed")
    }

    private static func check(
        _ actual: [String: String],
        equals expected: [String: String],
        name: String,
        failures: inout Int
    ) {
        guard actual == expected else {
            failures += 1
            fputs("FAIL \(name): got \(actual), expected \(expected)\n", stderr)
            return
        }
    }

    private static func policy(
        major: Int,
        minor: Int,
        autokill: Bool = false
    ) -> [String: String] {
        WineCompatibilityPolicy.recoveryPatchEnvironment(
            operatingSystemVersion: OperatingSystemVersion(
                majorVersion: major,
                minorVersion: minor,
                patchVersion: 0
            ),
            watchdogAutokillEnabled: autokill
        )
    }
}
