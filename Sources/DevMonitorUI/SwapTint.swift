import DevMonitorCore
import SwiftUI

/// The color that goes with a state of the swap, in the memory window and on its menu bar item.
enum SwapTint {
    /// Returns orange for a high swap and red for a critical one; nil while it is fine, which has no color of its own.
    /// @example SwapTint.color(for: .critical) // Palette.orphan
    static func color(for state: SwapState) -> Color? {
        switch state {
        case .fine: nil
        case .high: Palette.idle
        case .critical: Palette.orphan
        }
    }
}
