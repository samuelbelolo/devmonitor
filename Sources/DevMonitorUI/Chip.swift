import SwiftUI

/// A small rounded tag, e.g. a port or a state.
struct Chip: View {
    let text: String
    var tint: Color?

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(tint ?? Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background((tint ?? Color.primary).opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
            .fixedSize()
    }
}
