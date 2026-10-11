/// One command that updates every skill and plugin with an update, and how many of each it updates.
public struct UpdateAll: Sendable, Equatable {
    public let command: String
    public let skills: Int
    public let plugins: Int

    public init(command: String, skills: Int, plugins: Int) {
        self.command = command
        self.skills = skills
        self.plugins = plugins
    }
}
