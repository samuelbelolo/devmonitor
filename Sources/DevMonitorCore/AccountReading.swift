import Foundation

/// What the window knows of one account: the last usage read, when, and why the latest read did not give it.
public struct AccountReading: Sendable, Equatable {
    /// Why the latest read gave no usage.
    public enum Problem: Sendable, Equatable {
        case needsSignIn
        case throttled(until: Date)
        case unreachable
    }

    /// How long a read stays fresh enough for the window to open on it without reading again.
    private static let freshness: TimeInterval = 120

    public private(set) var usage: AccountUsage?
    public private(set) var readAt: Date?
    public private(set) var problem: Problem?

    public static let empty = AccountReading(usage: nil, readAt: nil, problem: nil)

    public init(usage: AccountUsage?, readAt: Date?, problem: Problem?) {
        self.usage = usage
        self.readAt = readAt
        self.problem = problem
    }

    /// Takes in the outcome of a read: a failed read keeps the last usage and its time, so the window shows it
    /// greyed with its age.
    /// @example reading.apply(.read(usage), at: Date())
    public mutating func apply(_ outcome: UsageReadOutcome, at now: Date) {
        switch outcome {
        case .read(let fresh):
            usage = fresh
            readAt = now
            problem = nil
        case .needsSignIn:
            problem = .needsSignIn
        case .throttled(let until):
            problem = .throttled(until: until)
        case .unreachable:
            problem = .unreachable
        }
    }

    /// Whether the window should read the account again when it opens: never read, or read more than two minutes ago.
    /// @example reading.isDue(at: Date()) // true
    public func isDue(at now: Date) -> Bool {
        readAt.map { now.timeIntervalSince($0) > Self.freshness } ?? true
    }
}
