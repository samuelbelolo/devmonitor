import DevMonitorCore
import SwiftUI

/// The Compose containers of a project, shown as one line.
struct ContainersRowView: View {
    let containers: [DockerContainer]
    @EnvironmentObject private var store: MonitorStore
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.ok).frame(width: 7, height: 7)
            BrandIconView(icon: .docker).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Docker")
                Text(containers.map(\.name).joined(separator: ", ")).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            ConfirmButton(title: Strings.stop) { store.stop(containers: containers) }
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
            Text(DisplayFormat.memory(containers.reduce(0) { $0 + $1.memoryBytes })).monospacedDigit().fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .background(isHovered ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .onHover { isHovered = $0 }
    }
}
