import Foundation

/// Tells which agent sessions are working, from the CPU time they used between two scans.
public struct WorkTracker: Sendable {
    private struct Sample: Sendable {
        var cpuTimeNs: UInt64
        var date: Date
    }

    private var samples: [String: Sample] = [:]
    /// Percent of one core above which a session counts as working: it streams, renders or runs a tool.
    public static let workingThreshold = 2.0
    /// Longest gap between two scans that still counts: beyond it the Mac was asleep.
    public static let maximumGap: TimeInterval = 120

    public init() {}

    /// Records the CPU time of each session and returns the ids of those that worked since the previous scan.
    /// Sessions no longer given are forgotten.
    /// @example tracker.record(sessions, at: Date()) // ["4242-1700000000"]
    public mutating func record(_ sessions: [AgentSession], at date: Date) -> Set<String> {
        var working: Set<String> = []
        var next: [String: Sample] = [:]
        for session in sessions {
            let now = Sample(cpuTimeNs: session.cpuTimeNs, date: date)
            if let before = samples[session.id] {
                let elapsed = date.timeIntervalSince(before.date)
                let spent = now.cpuTimeNs > before.cpuTimeNs ? Double(now.cpuTimeNs - before.cpuTimeNs) : 0
                if elapsed > 0, elapsed <= Self.maximumGap, spent / elapsed / 1e9 * 100 > Self.workingThreshold {
                    working.insert(session.id)
                }
            }
            next[session.id] = now
        }
        samples = next
        return working
    }
}
