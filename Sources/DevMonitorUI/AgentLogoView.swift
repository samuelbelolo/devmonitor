import DevMonitorCore
import SwiftUI

/// An agent's logo, in its brand color when it has one.
struct AgentLogoView: View {
    let agent: Agent
    var size: CGFloat = 13
    /// Draws the logo pale, for a session that waits.
    var isDimmed = false
    /// Replaces the brand color, e.g. on the agent's tile.
    var color: Color? = nil

    var body: some View {
        Group {
            if let icon = BrandIcon.agent(agent) { BrandIconView(icon: icon, size: size) } else {
                Image(systemName: "terminal").font(.system(size: size * 0.8)).frame(width: size, height: size)
            }
        }
        .foregroundStyle(color ?? AgentBrand.tint(agent) ?? Color.primary)
            .opacity(isDimmed ? 0.4 : 1)
    }
}
