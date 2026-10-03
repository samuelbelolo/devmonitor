import Foundation

/// Recognises an MCP server from the words of its command, for servers whose agent is gone.
enum McpCommand {
    private static let names: Set<String> = ["mcp", "serena"]

    /// Whether a command line names an MCP server: a word of an argument's file name is "mcp" or a known server.
    /// A folder named after MCP is not enough, so a dev server in `my-mcp-tools/` stays in its project.
    /// @example McpCommand.matches(["npm exec chrome-devtools-mcp@1.1.1"]) // true
    static func matches(_ arguments: [String]) -> Bool {
        arguments.flatMap { $0.split(separator: " ") }.contains { token in
            let file = (String(token) as NSString).lastPathComponent.lowercased()
            return file.split { !$0.isLetter && !$0.isNumber }.contains { names.contains(String($0)) }
        }
    }
}
