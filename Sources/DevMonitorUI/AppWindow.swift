import DevMonitorCore

/// One of the app's windows: the memory window, or the window of one agent's menu bar item.
public enum AppWindow: Hashable, Sendable {
    case memory
    case agent(Agent)
}
