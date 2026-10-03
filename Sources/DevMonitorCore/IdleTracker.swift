import Foundation

/// Remembers the CPU time of each service's processes between scans, to tell how long a service has done nothing.
public struct IdleTracker: Sendable {
    private struct Sample: Sendable {
        var cpuByProcess: [String: UInt64]
        var date: Date
        var lastActive: Date
    }

    private var samples: [String: Sample] = [:]
    /// Percent of one core above which a service counts as active.
    public static let activeThreshold = 0.5
    /// Seconds without activity before a service is called idle.
    public static let idleThreshold: TimeInterval = 600
    /// Longest gap between two scans that still counts: beyond it the Mac was asleep, and that time proves nothing.
    public static let maximumGap: TimeInterval = 120

    public init() {}

    /// Records the CPU time of a service's processes and returns how many seconds it has been idle, once past
    /// the idle threshold. A process that appears or disappears counts as activity.
    /// @example tracker.record(service, at: tenMinutesAfterTheLastCpuUse) // 600
    public mutating func record(_ service: Service, at date: Date) -> Int? {
        let cpuByProcess = Dictionary(service.members.map { ($0.identity, $0.cpuTimeNs) }, uniquingKeysWith: { first, _ in first })
        guard var sample = samples[service.id] else {
            samples[service.id] = Sample(cpuByProcess: cpuByProcess, date: date, lastActive: date)
            return nil
        }
        let elapsed = date.timeIntervalSince(sample.date)
        let spent = cpuByProcess.reduce(0.0) { total, entry in
            let before = sample.cpuByProcess[entry.key] ?? entry.value
            return total + (entry.value > before ? Double(entry.value - before) : 0)
        }
        let percent = elapsed > 0 ? spent / elapsed / 1e9 * 100 : 0
        let membersChanged = Set(cpuByProcess.keys) != Set(sample.cpuByProcess.keys)
        if membersChanged || percent > Self.activeThreshold || elapsed > Self.maximumGap { sample.lastActive = date }
        sample.cpuByProcess = cpuByProcess
        sample.date = date
        samples[service.id] = sample
        let idle = date.timeIntervalSince(sample.lastActive)
        return idle >= Self.idleThreshold ? Int(idle) : nil
    }

    /// Forgets the services that no longer exist.
    /// @example tracker.prune(keeping: ["40-100"])
    public mutating func prune(keeping ids: Set<String>) {
        samples = samples.filter { ids.contains($0.key) }
    }
}
