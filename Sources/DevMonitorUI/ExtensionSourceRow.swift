import DevMonitorCore
import SwiftUI

/// One repository of skills or marketplace of plugins: its counts, then what to do about it when expanded.
struct ExtensionSourceRow: View {
    let source: ExtensionSource
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary).frame(width: 9)
                Text(source.name).fontWeight(.semibold).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 6)
                if source.updates > 0 { Chip(text: Strings.updates(source.updates), tint: Palette.idle) }
                if source.moved > 0 { Chip(text: Strings.moved(source.moved), tint: Palette.orphan) }
                if source.unknown > 0 { Chip(text: Strings.unknown) }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            if isExpanded { details.padding(.leading, 15) }
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder private var details: some View {
        switch source.kind {
        case .skills:
            // One command for the repository: every name it updates is in it, the line above shows the first ones.
            if let command = source.command {
                note(Strings.names(source.outdated.map(\.name)), color: .secondary)
                CopyCommandView(command: command)
            }
        case .plugins:
            ForEach(source.outdated) { item in
                HStack(spacing: 5) {
                    Text(item.name).lineLimit(1)
                    if let detail = item.detail { Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                }
                if let command = item.command { CopyCommandView(command: command) }
            }
        }
        if source.moved > 0 { note(Strings.movedNote(source.moved), color: Palette.idle) }
        if let reason = source.unknownReason { note(Strings.unknownReason(reason), color: .secondary) }
    }

    /// Returns a small line of explanation that wraps instead of widening the window.
    /// @example note("18 moved", color: Palette.idle)
    private func note(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}
