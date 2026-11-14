import DevMonitorCore
import SwiftUI

/// The menu bar label of the memory item: the chip, orange or red once the swap is high or critical, then the memory
/// the projects use.
public struct MemoryMenuBarLabel: View {
    @EnvironmentObject private var store: MonitorStore

    public init() {}

    public var body: some View {
        if let image = MemoryGlyph.image(for: store.swap?.state ?? .fine) {
            Image(nsImage: image)
        } else {
            Image(systemName: "memorychip")
        }
        Text(DisplayFormat.memory(store.totalBytes))
    }
}
