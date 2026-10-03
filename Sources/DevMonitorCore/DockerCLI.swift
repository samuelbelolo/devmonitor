import Foundation

/// Talks to the local Docker daemon through the `docker` command-line tool, only when a daemon socket exists.
public enum DockerCLI {
    private static let executables = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", NSHomeDirectory() + "/.docker/bin/docker", "/Applications/Docker.app/Contents/Resources/bin/docker"]
    /// Docker Desktop, OrbStack, Colima, Rancher Desktop, then the system-wide socket.
    private static let sockets = [".docker/run/docker.sock", ".orbstack/run/docker.sock", ".colima/default/docker.sock", ".rd/docker.sock"]
        .map { NSHomeDirectory() + "/" + $0 } + ["/var/run/docker.sock"]
    private static let listFormat = #"{{.ID}}\#t{{.Names}}\#t{{.Label "com.docker.compose.project"}}\#t{{.Label "com.docker.compose.project.working_dir"}}"#
    private static let statsFormat = "{{.ID}}\t{{.MemUsage}}"
    private static let readTimeout: TimeInterval = 10

    /// Returns the running Compose containers with their memory, from the first daemon that answers;
    /// an empty list when Docker is not running.
    /// @example DockerCLI.containers().map(\.name) // ["shop-cache-1", "shop-db-1"]
    public static func containers() -> [DockerContainer] {
        for socket in sockets where FileManager.default.fileExists(atPath: socket) {
            guard let listing = run(["ps", "--format", listFormat], socket: socket, timeout: readTimeout) else { continue }
            let containers = DockerOutputParser.containers(from: listing)
            guard !containers.isEmpty,
                  let stats = run(["stats", "--no-stream", "--format", statsFormat], socket: socket, timeout: readTimeout)
            else { return containers }
            let memory = DockerOutputParser.memory(from: stats)
            return containers.map { container in
                var measured = container
                measured.memoryBytes = memory[container.id] ?? 0
                return measured
            }
        }
        return []
    }

    /// Stops containers by id; returns whether a daemon accepted the command.
    /// @example DockerCLI.stop(["abc123"]) // true
    @discardableResult
    public static func stop(_ ids: [String]) -> Bool {
        guard !ids.isEmpty else { return false }
        // Docker waits up to 10 s per container before it kills it, one container after the other.
        let timeout = 20 + 12 * TimeInterval(ids.count)
        return sockets.contains { socket in
            FileManager.default.fileExists(atPath: socket) && run(["stop", "--"] + ids, socket: socket, timeout: timeout) != nil
        }
    }

    /// Runs a docker command against one local socket and returns its output; nil when the tool is absent,
    /// the command fails, or it has not finished after `timeout` seconds. The socket is given explicitly
    /// so a remote context or `DOCKER_HOST` set by the user is never followed.
    /// @example run(["ps", "-q"], socket: "/var/run/docker.sock", timeout: 10) // "abc123\n"
    private static func run(_ arguments: [String], socket: String, timeout: TimeInterval) -> String? {
        guard let executable = executables.first(where: FileManager.default.isExecutableFile) else { return nil }
        return CommandRunner.run(executable, ["-H", "unix://" + socket] + arguments, timeout: timeout)
    }
}
