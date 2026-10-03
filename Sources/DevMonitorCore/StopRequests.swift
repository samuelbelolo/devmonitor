import Foundation

/// Remembers when each process was asked to stop, so a process that outlives its parent can still be force-quit.
public struct StopRequests: Equatable, Sendable {
    private var dates: [String: Date] = [:]

    public init() {}

    /// Records a stop request for every process of the services; an earlier request for a process keeps its date.
    /// @example requests.record([service], at: Date())
    public mutating func record(_ services: [Service], at date: Date) {
        for member in services.flatMap(\.members) where dates[member.identity] == nil {
            dates[member.identity] = date
        }
    }

    /// Returns when a stop was first requested for one of the service's processes, or nil when none was.
    /// @example requests.date(for: service) // 2026-01-01 10:00:00 +0000
    public func date(for service: Service) -> Date? {
        service.members.compactMap { dates[$0.identity] }.min()
    }

    /// Forgets the requests whose process no longer runs.
    /// @example requests.prune(keeping: ["50-100"])
    public mutating func prune(keeping identities: Set<String>) {
        dates = dates.filter { identities.contains($0.key) }
    }
}
