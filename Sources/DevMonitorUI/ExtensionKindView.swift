import DevMonitorCore
import SwiftUI

/// The skills, or the plugins: one collapsed line, then their sources when expanded.
struct ExtensionKindView: View {
    let kind: ExtensionKind
    let sources: [ExtensionSource]
    /// A warning shown under the sources, with the command that answers it.
    var warning: (text: String, command: String)?

    @State private var isExpanded = false
    /// The natural height of the source list; a ScrollView has none, so the window would collapse it to zero.
    @State private var listHeight: CGFloat = 0
    private static let maximumListHeight: CGFloat = 300

    private var attention: [ExtensionSource] { sources.filter(\.needsAttention) }
    private var quiet: [ExtensionSource] { sources.filter { !$0.needsAttention } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary).frame(width: 9)
                Text(Strings.title(kind)).font(.system(size: 13.5, weight: .semibold))
                Text(Strings.installed(ExtensionReport.count(in: sources), sources: sources.count, kind: kind))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 6)
                let updates = ExtensionReport.updates(in: sources)
                if updates > 0 { Chip(text: Strings.updates(updates), tint: Palette.idle) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            if isExpanded {
                ScrollView {
                    list.background(GeometryReader { Color.clear.preference(key: ListHeightKey.self, value: $0.size.height) })
                }
                .frame(height: min(max(listHeight, 20), Self.maximumListHeight))
                .onPreferenceChange(ListHeightKey.self) { listHeight = $0 }
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(attention) { ExtensionSourceRow(source: $0) }
            if !quiet.isEmpty {
                Text(Strings.quietSources(quiet.count, items: ExtensionReport.count(in: quiet), kind: kind, others: !attention.isEmpty, checked: quiet.contains(where: \.isChecked)))
                    .font(.system(size: 11)).foregroundStyle(.tertiary).padding(.horizontal, 6)
            }
            if let warning {
                Text(warning.text).font(.system(size: 11)).foregroundStyle(Palette.idle).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 6)
                CopyCommandView(command: warning.command).padding(.horizontal, 6)
            }
        }
        .padding(.leading, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
