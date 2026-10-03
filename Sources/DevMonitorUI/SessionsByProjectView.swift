import DevMonitorCore
import SwiftUI

/// The agent sessions grouped by the project they were started in, one logo per session.
struct SessionsByProjectView: View {
    let sessions: [AgentSession]
    let working: Set<String>

    private struct Project: Identifiable {
        let id: String
        let name: String
        let sessions: [AgentSession]
    }

    /// Projects with the most sessions first, then by name; sessions outside any project last.
    private var projects: [Project] {
        Dictionary(grouping: sessions) { $0.location?.root ?? "" }
            .map { root, sessions in Project(id: root, name: root.isEmpty ? Strings.outsideProjects : (sessions[0].location?.name ?? root), sessions: sessions) }
            .sorted { ($0.id.isEmpty ? 1 : 0, -$0.sessions.count, $0.name) < ($1.id.isEmpty ? 1 : 0, -$1.sessions.count, $1.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(projects) { project in
                HStack(spacing: 8) {
                    Circle().fill(project.id.isEmpty ? Color.secondary : Palette.color(for: project.id)).frame(width: 8, height: 8)
                    Text(project.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 6)
                    HStack(spacing: 3) {
                        ForEach(project.sessions.prefix(8)) { session in
                            AgentLogoView(agent: session.agent, size: 11, isDimmed: !working.contains(session.id))
                        }
                    }
                    Text("\(project.sessions.count)").fontWeight(.bold).monospacedDigit().frame(minWidth: 14, alignment: .trailing)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            HStack(spacing: 12) {
                Label { Text(Strings.working) } icon: { AgentLogoView(agent: .claude, size: 10) }
                Label { Text(Strings.waiting) } icon: { AgentLogoView(agent: .claude, size: 10, isDimmed: true) }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
    }
}
