import DevMonitorCore
import SwiftUI

/// A project: its header, then its services and containers when expanded.
struct GroupSection: View {
    let group: ProjectGroup
    @EnvironmentObject private var store: MonitorStore
    @State private var isExpanded: Bool
    @State private var isHovered = false

    init(group: ProjectGroup) {
        self.group = group
        _isExpanded = State(initialValue: group.kind == .project)
    }

    private var title: String { group.kind == .mcpServers ? Strings.mcpServers : group.name }

    private var summary: String {
        let processes = group.processCount > 0 ? Strings.processes(group.processCount) : nil
        let containers = group.containers.isEmpty ? nil : Strings.containers(group.containers.count)
        return [processes, containers].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Divider().padding(.bottom, 6)
            HStack(spacing: 8) {
                Circle().fill(Palette.color(for: group.id)).frame(width: 8, height: 8)
                Text(title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Text(summary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 6)
                // Always laid out and only revealed on hover, so hovering never shifts the line.
                ConfirmButton(title: Strings.stop) { store.stop(group) }
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
                Text(DisplayFormat.memory(group.memoryBytes)).monospacedDigit().fixedSize()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .onHover { isHovered = $0 }
            if isExpanded {
                ForEach(group.rows) { ServiceRowView(row: $0) }
                if !group.containers.isEmpty { ContainersRowView(containers: group.containers) }
            }
        }
    }
}
