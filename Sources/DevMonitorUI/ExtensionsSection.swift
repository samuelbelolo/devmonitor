import DevMonitorCore
import SwiftUI

/// The skills and plugins installed on this Mac, under the agents' versions; hidden when there are none.
struct ExtensionsSection: View {
    @EnvironmentObject private var extensions: ExtensionStore

    var body: some View {
        let report = extensions.report
        if !report.isEmpty {
            Divider()
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(title: Strings.extensions)
                Spacer()
                if let checkedAt = extensions.checkedAt {
                    let seconds = Int(Date().timeIntervalSince(checkedAt))
                    Text(Strings.checked(ago: DisplayFormat.duration(seconds: seconds))).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            if !report.skills.isEmpty {
                ExtensionKindView(kind: .skills, sources: report.skills)
            }
            if !report.plugins.isEmpty {
                ExtensionKindView(
                    kind: .plugins, sources: report.plugins,
                    warning: report.staleCatalogs > 0 ? (Strings.staleCatalogs(report.staleCatalogs), ExtensionCommand.refreshMarketplaces) : nil)
            }
        }
    }
}
