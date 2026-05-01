import SwiftUI

extension Color {
    /// Battle.net's brand blue — used in their desktop client's primary
    /// buttons and accent strokes. Sampled from their UI screenshots.
    static let bnetBlue       = Color(red: 0.078, green: 0.557, blue: 1.000) // #148EFF
    static let bnetBlueDeep   = Color(red: 0.000, green: 0.420, blue: 0.882) // #006BE0
    static let bnetBlueLight  = Color(red: 0.275, green: 0.667, blue: 1.000) // #46AAFF

    /// App backdrop — deep slate with a subtle warm shift bottom-to-top
    /// so the gradient is perceptible without competing with content.
    static let appBgTop       = Color(red: 0.043, green: 0.055, blue: 0.090) // #0B0E17
    static let appBgBottom    = Color(red: 0.078, green: 0.094, blue: 0.137) // #141823

    /// Foreground tints for dark backdrop. macOS's semantic colors handle
    /// most text but headlines + captions read better with explicit values.
    static let appHeadline    = Color(red: 0.957, green: 0.965, blue: 0.984) // #F4F6FB
    static let appSubhead     = Color(red: 0.706, green: 0.733, blue: 0.804) // #B4BBCD
    static let appCaption     = Color(red: 0.490, green: 0.522, blue: 0.604) // #7D859A
}
