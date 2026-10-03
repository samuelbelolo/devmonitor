import Foundation

/// What happened to one process when a signal was requested.
public enum KillOutcome: Equatable, Sendable {
    case signalled(Int32)
    /// The process ended, its pid now belongs to another process, or it became another program.
    case gone(Int32)
    /// The process is protected and was left alone.
    case refused(Int32)
    case failed(Int32)
}
