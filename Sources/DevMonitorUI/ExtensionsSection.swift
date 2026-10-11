import DevMonitorCore
import SwiftUI

/// The skills and plugins installed on this Mac, under the agents' versions; hidden when there are none.
struct ExtensionsSection: View {
    @EnvironmentObject private var extensions: ExtensionStore

    var body: some View {
        let report = extensions.report
        if !report.isEmpty {
            Divider()
            ExtensionsHeader()
            // Shown only when it saves commands: with a single source to update, its own command is the same.
            if report.separateUpdateCommands > 1, let command = report.updateAllCommand {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Strings.updateAll(skills: ExtensionReport.updates(in: report.skills), plugins: ExtensionReport.updates(in: report.plugins)))
                        .font(.system(size: 11)).foregroundStyle(Palette.idle)
                    CopyCommandView(command: command)
                }
                .padding(.horizontal, 6)
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
