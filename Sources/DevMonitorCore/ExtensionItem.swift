/// One installed skill or plugin as the window lists it.
public struct ExtensionItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    /// A plugin's installed version, and its scope when it is not `user`.
    public let detail: String?
    public let state: ExtensionState
    /// The command that updates this item alone; nil when it has none or shares its source's command.
    public let command: String?

    public init(id: String, name: String, detail: String?, state: ExtensionState, command: String?) {
        self.id = id
        self.name = name
        self.detail = detail
        self.state = state
        self.command = command
    }
}
