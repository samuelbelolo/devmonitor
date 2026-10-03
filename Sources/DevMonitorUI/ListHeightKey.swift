import SwiftUI

/// Carries the measured height of the project list up to the view that sizes its scroll area.
struct ListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    /// Keeps the largest height reported during a layout pass.
    /// @example reduce(value: &height) { 320 } // height == 320
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
