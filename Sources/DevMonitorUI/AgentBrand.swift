import AppKit
import DevMonitorCore
import SwiftUI

/// How each agent is drawn: its logo, the color of that logo, and the tile behind it in the versions list.
enum AgentBrand {
    static let claudeOrange = Color(red: 0.851, green: 0.467, blue: 0.341)

    /// Returns the agent's logo as a template image, or a terminal symbol for an agent without one.
    /// @example AgentBrand.logo(.amp) // the terminal symbol
    static func logo(_ agent: Agent) -> NSImage {
        BrandIcon.agent(agent)?.image ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
    }

    /// Returns the color of the logo in a window or the menu bar; nil keeps the text color.
    /// @example AgentBrand.tint(.claude) // claudeOrange
    static func tint(_ agent: Agent) -> Color? {
        switch agent {
        case .claude: claudeOrange
        case .codex, .gemini, .aider, .opencode, .cursorAgent, .amp: nil
        }
    }

    /// Returns the tile color and the logo color of the agent in the versions list.
    /// @example AgentBrand.tile(.codex).background // .white
    static func tile(_ agent: Agent) -> (background: Color, logo: Color) {
        switch agent {
        case .claude: (claudeOrange, .white)
        case .codex: (.white, .black)
        case .gemini, .aider, .opencode, .cursorAgent, .amp: (.black, .white)
        }
    }
}
