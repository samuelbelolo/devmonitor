import Foundation

/// Runs work that blocks its thread, such as waiting for the docker tool.
enum BlockingWork {
    /// Runs the work on a background queue, so it never holds one of the few threads Swift tasks share.
    /// @example await BlockingWork.run { DockerCLI.containers() } // [DockerContainer]
    static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { continuation.resume(returning: work()) }
        }
    }
}
