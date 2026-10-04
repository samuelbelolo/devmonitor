import DevMonitorCore
import SwiftUI

/// One installed agent: its version, its sessions, whether it is up to date, and how to update it.
struct AgentVersionRow: View {
    let report: AgentVersionReport
    let sessions: [AgentSession]

    private var toRestart: [AgentSession] { report.sessionsToRestart(among: sessions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 9) {
                AgentLogoView(agent: report.agent, size: 14, color: AgentBrand.tile(report.agent).logo)
                    .frame(width: 24, height: 24)
                    .background(AgentBrand.tile(report.agent).background, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(report.agent.displayName).fontWeight(.semibold)
                        Text(report.installed?.text ?? "?").foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 6)
                status
            }
            if !toRestart.isEmpty {
                Text(Strings.toRestart(toRestart.count, oldest: toRestart.compactMap(\.version).min()?.text ?? ""))
                    .font(.system(size: 11)).foregroundStyle(Palette.idle).lineLimit(1).padding(.leading, 33)
            }
            if report.isOutdated { CopyCommandView(command: AgentRelease.updateCommand(for: report.agent)).padding(.leading, 33) }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    /// The sessions line; it also says when the latest version is unknown, which needs no chip.
    private var subtitle: String {
        let sessionsText = Strings.openSessions(sessions.count)
        return report.installed != nil && report.latest == nil ? sessionsText + " · " + Strings.latestUnknown : sessionsText
    }

    @ViewBuilder private var status: some View {
        if report.installed == nil {
            Chip(text: Strings.versionUnreadable)
        } else if let latest = report.latest {
            report.isOutdated ? Chip(text: Strings.available(latest.text), tint: Palette.idle) : Chip(text: Strings.upToDate, tint: Palette.ok)
        }
    }
}
