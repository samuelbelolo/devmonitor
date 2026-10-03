import Foundation

/// The parent/child relations between the processes of one scan.
public struct ProcessTree: Sendable {
    public let snapshots: [ProcessSnapshot]
    private let byPid: [Int32: ProcessSnapshot]
    private let childrenByParent: [Int32: [ProcessSnapshot]]

    public init(_ snapshots: [ProcessSnapshot]) {
        self.snapshots = snapshots
        byPid = Dictionary(snapshots.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        childrenByParent = Dictionary(grouping: snapshots, by: \.ppid)
    }

    /// Returns the process with this pid, if it was scanned.
    /// @example tree.snapshot(pid: 50)?.name // "node"
    public func snapshot(pid: Int32) -> ProcessSnapshot? {
        byPid[pid]
    }

    /// Returns the direct children of a process, ordered by pid.
    /// @example tree.children(of: 40).map(\.pid) // [50]
    public func children(of pid: Int32) -> [ProcessSnapshot] {
        (childrenByParent[pid] ?? []).filter { $0.pid != pid }.sorted { $0.pid < $1.pid }
    }

    /// Returns every descendant of a process, children before grandchildren.
    /// @example tree.descendants(of: 30).map(\.pid) // [40, 50]
    public func descendants(of pid: Int32) -> [ProcessSnapshot] {
        var result: [ProcessSnapshot] = []
        var seen: Set<Int32> = [pid]
        var queue = children(of: pid)
        while !queue.isEmpty {
            let next = queue.removeFirst()
            guard seen.insert(next.pid).inserted else { continue }
            result.append(next)
            queue.append(contentsOf: children(of: next.pid))
        }
        return result
    }

    /// Returns the ancestors of a process, nearest parent first.
    /// @example tree.ancestors(of: 50).map(\.pid) // [40, 30, 20, 10]
    public func ancestors(of pid: Int32) -> [ProcessSnapshot] {
        var result: [ProcessSnapshot] = []
        var seen: Set<Int32> = [pid]
        var current = byPid[pid]
        while let parent = current.flatMap({ byPid[$0.ppid] }), seen.insert(parent.pid).inserted {
            result.append(parent)
            current = parent
        }
        return result
    }
}
