import DevMonitorCore
import SwiftUI

/// The colour of a limit once it is nearly used up: a strong orange from 80 %, turning red by 95 %, so a full account
/// stands out at a glance.
enum LimitTint {
    /// The orange a limit takes at 80 % used.
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
    private static let from: Double = 80

    /// Returns the colour of a share used: none below 80 %, then orange blending into red, red from 95 %.
    /// @example LimitTint.color(percentUsed: 96) // Palette.orphan
    static func color(percentUsed: Double) -> Color? {
        guard percentUsed >= from else { return nil }
        if percentUsed >= AccountLimit.fullAt { return Palette.orphan }
        let toRed = (percentUsed - from) / (AccountLimit.fullAt - from)
        return Color(red: 1.0, green: 0.58 - 0.16 * toRed, blue: 0.42 * toRed)
    }
}
