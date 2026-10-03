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
                        Text(report.agent.displayName).fontWeight(.semibold).lineLimit(1).fixedSize()
                        Text(report.installed?.text ?? "?").foregroundStyle(.secondary)
                    }
                    Text(Strings.openSessions(sessions.count)).font(.system(size: 11)).foregroundStyle(.secondary)
                    if !toRestart.isEmpty {
                        Text(Strings.toRestart(toRestart.count, oldest: toRestart.compactMap(\.version).min()?.text ?? ""))
                            .font(.system(size: 11)).foregroundStyle(Palette.idle)
                    }
                }
                Spacer(minLength: 6)
                status
            }
            if report.isOutdated { CopyCommandView(command: AgentRelease.updateCommand(for: report.agent)).padding(.leading, 33) }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    @ViewBuilder private var status: some View {
        if report.installed == nil {
            Chip(text: Strings.versionUnreadable)
        } else if let latest = report.latest {
            report.isOutdated ? Chip(text: Strings.available(latest.text), tint: Palette.idle) : Chip(text: Strings.upToDate, tint: Palette.ok)
        } else {
            Chip(text: Strings.latestUnknown)
        }
    }
}
