import Foundation

/// One line of a group: a single service, or several identical ones shown together.
public struct ServiceRow: Identifiable, Equatable, Sendable {
    public let label: String
    public let services: [Service]

    public var id: String { services.map(\.id).joined(separator: "+") }
    public var memoryBytes: UInt64 { services.reduce(0) { $0 + $1.memoryBytes } }
    public var ports: [UInt16] { Array(Set(services.flatMap(\.ports))).sorted() }
    /// Whether every service of the line lost its parent.
    public var isOrphan: Bool { services.allSatisfy(\.isOrphan) }
}
