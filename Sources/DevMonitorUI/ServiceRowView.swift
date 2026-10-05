import DevMonitorCore
import SwiftUI

/// One line of a group: a service (or several identical ones), its state and its stop button.
struct ServiceRowView: View {
    let row: ServiceRow
    @EnvironmentObject private var store: MonitorStore
    @State private var isHovered = false

    private var first: Service { row.services[0] }
    private var idleSeconds: Int? { row.services.compactMap { store.idleSeconds[$0.id] }.min() }
    private var isIdle: Bool { row.services.allSatisfy { store.idleSeconds[$0.id] != nil } }
    private var canForce: Bool { row.services.contains(where: store.canForce) }
    private var isStopping: Bool { row.services.contains(where: store.isStopping) }

    private var stateColor: Color { row.isOrphan ? Palette.orphan : isIdle ? Palette.idle : Palette.ok }

    private var detail: String {
        let count = row.services.count > 1 ? "×\(row.services.count)" : nil
        let place = row.services.count > 1 ? nil : [first.location.worktree, first.location.package].compactMap { $0 }.joined(separator: " · ")
        return [count, place].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The ports, then the orphan and idle states.
    @ViewBuilder private var chips: some View {
        ForEach(row.ports.prefix(2), id: \.self) { Chip(text: ":\($0)") }
        if row.isOrphan { Chip(text: Strings.orphan, tint: Palette.orphan) }
        if let idleSeconds, isIdle { Chip(text: Strings.idle(for: DisplayFormat.duration(seconds: idleSeconds)), tint: Palette.idle) }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(stateColor).frame(width: 7, height: 7)
            // A fixed slot keeps labels aligned whether or not the runtime has a logo.
            Group {
                if let icon = BrandIcon.runtime(of: first) { BrandIconView(icon: icon) } else { Color.clear }
            }
            .frame(width: 13, height: 13)
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                // The chips never shrink, so on a narrow line they would squeeze the name down to "…":
                // when both do not fit side by side, the chips go under the name.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 5) {
                        Text(row.label).lineLimit(1).fixedSize()
                        chips
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label).lineLimit(1).truncationMode(.middle)
                        HStack(spacing: 5) { chips }
                    }
                }
                HStack(spacing: 4) {
                    if !detail.isEmpty { Text(detail).lineLimit(1).truncationMode(.middle) }
                    if let agent = first.agent {
                        if !detail.isEmpty { Text("·") }
                        if let icon = BrandIcon.agent(agent) { BrandIconView(icon: icon, size: 10) }
                        Text(Strings.startedBy(agent.displayName)).lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if canForce {
                ConfirmButton(title: Strings.force) { store.stop(row.services, force: true) }
            } else {
                // The spinner or the cross share one fixed slot, so neither hovering nor the confirm label,
                // drawn over the line, ever shifts it.
                ZStack {
                    if isStopping {
                        ProgressView().controlSize(.small)
                    } else {
                        ConfirmButton(title: Strings.stop, systemImage: "xmark.circle.fill") { store.stop(row.services) }
                            .opacity(isHovered ? 1 : 0)
                            .allowsHitTesting(isHovered)
                    }
                }
                .frame(width: 18, height: 18)
            }
            Text(DisplayFormat.memory(row.memoryBytes)).monospacedDigit().fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .background(isHovered ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .onHover { isHovered = $0 }
    }
}
