import SwiftUI

protocol AppTheme {
    var id: String { get }
    var displayName: String { get }
    var requiredEntitlement: String? { get }

    var background: Color { get }
    var surface: Color { get }
    var accent: Color { get }
    var titleGradient: [Color] { get }
}

extension AppTheme {
    var isPaid: Bool { requiredEntitlement != nil }
}

// MARK: - Stock (always available)

struct BattleNetTheme: AppTheme {
    let id = "stock-bnet"
    let displayName = "Battle.net"
    let requiredEntitlement: String? = nil

    let background = Color(red: 0.051, green: 0.067, blue: 0.090)
    let surface    = Color(red: 0.086, green: 0.106, blue: 0.133)
    let accent     = Color(red: 0.000, green: 0.682, blue: 1.000)
    var titleGradient: [Color] { [.white, accent] }
}

struct MidnightTheme: AppTheme {
    let id = "stock-midnight"
    let displayName = "Midnight"
    let requiredEntitlement: String? = nil

    let background = Color(red: 0.039, green: 0.039, blue: 0.043)
    let surface    = Color(red: 0.102, green: 0.102, blue: 0.114)
    let accent     = Color(white: 0.95)
    var titleGradient: [Color] { [.white, Color(white: 0.55)] }
}

// MARK: - Paid skins (require entitlement)

struct TristramTheme: AppTheme {
    let id = "skin-tristram"
    let displayName = "Tristram"
    let requiredEntitlement: String? = "skin-tristram"

    let background = Color(red: 0.102, green: 0.059, blue: 0.031)
    let surface    = Color(red: 0.165, green: 0.102, blue: 0.059)
    let accent     = Color(red: 0.722, green: 0.188, blue: 0.188)
    var titleGradient: [Color] {
        [Color(red: 0.941, green: 0.878, blue: 0.690), accent]
    }
}
