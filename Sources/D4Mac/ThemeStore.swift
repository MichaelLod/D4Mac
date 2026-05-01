import Foundation
import Observation

@Observable
@MainActor
final class ThemeStore {
    let available: [any AppTheme]
    private(set) var current: any AppTheme

    private let entitlements: EntitlementStore
    private let storageKey = "selectedThemeId"

    init(entitlements: EntitlementStore) {
        self.entitlements = entitlements
        let all: [any AppTheme] = [
            BattleNetTheme(),
            MidnightTheme(),
            TristramTheme(),
        ]
        self.available = all
        self.current = all[0]
        if let savedId = UserDefaults.standard.string(forKey: storageKey),
           let saved = all.first(where: { $0.id == savedId }),
           Self.canUse(saved, with: entitlements) {
            self.current = saved
        }
    }

    func canUse(_ theme: any AppTheme) -> Bool {
        Self.canUse(theme, with: entitlements)
    }

    func select(_ theme: any AppTheme) {
        guard canUse(theme) else { return }
        current = theme
        UserDefaults.standard.set(theme.id, forKey: storageKey)
    }

    /// Downgrade to the first stock theme if the user lost access to the
    /// currently-applied paid skin (e.g. after a refund or `reset()`).
    func reconcile() {
        if !canUse(current) {
            current = available[0]
            UserDefaults.standard.set(current.id, forKey: storageKey)
        }
    }

    private static func canUse(_ theme: any AppTheme, with entitlements: EntitlementStore) -> Bool {
        guard let required = theme.requiredEntitlement else { return true }
        return entitlements.owns(required)
    }
}
