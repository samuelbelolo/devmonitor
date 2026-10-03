import DevMonitorCore
import SwiftUI

/// A bar split between projects in proportion to their memory.
struct MemoryMeter: View {
    let groups: [ProjectGroup]
    let total: UInt64

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(groups) { group in
                    Palette.color(for: group.id)
                        .frame(width: max(geometry.size.width * CGFloat(group.memoryBytes) / CGFloat(max(total, 1)) - 2, 2))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}
