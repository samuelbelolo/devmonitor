import SwiftUI

/// The small capitalised title of a section of a window.
struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(0.6).foregroundStyle(.secondary).padding(.top, 2)
    }
}
