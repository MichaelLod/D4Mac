import Foundation
import Observation

@Observable
@MainActor
final class EntitlementStore {
    private(set) var ownedSkins: Set<String> = []
    private(set) var hasLicense: Bool = false

    init() { loadFromKeychain() }

    /// Apply a fresh JWT received from `d4mac://activate?token=…`.
    /// Verifies signature and claims before persisting.
    func ingest(_ jwt: String) throws {
        let payload = try LicenseVerifier.verify(jwt)
        try LicenseVerifier.store(jwt)
        apply(payload.entitlements)
    }

    /// Whether a given skin is unlocked. Honours the wildcard `skin-*`.
    func owns(_ skinId: String) -> Bool {
        ownedSkins.contains("skin-*") || ownedSkins.contains(skinId)
    }

    func reset() {
        LicenseVerifier.clearStored()
        ownedSkins = []
        hasLicense = false
    }

    private func loadFromKeychain() {
        guard let jwt = LicenseVerifier.loadStored(),
              let payload = try? LicenseVerifier.verify(jwt)
        else { return }
        apply(payload.entitlements)
    }

    private func apply(_ entitlements: [String]) {
        ownedSkins = Set(entitlements)
        hasLicense = !entitlements.isEmpty
    }
}
