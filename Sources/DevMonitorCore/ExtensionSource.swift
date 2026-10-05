/// A repository of skills or a marketplace of plugins, with what is installed from it.
public struct ExtensionSource: Identifiable, Sendable, Equatable {
    public let kind: ExtensionKind
    public let name: String
    public let items: [ExtensionItem]
    /// One command that updates every item of the source with an update; nil when each item has its own.
    public let command: String?

    public init(kind: ExtensionKind, name: String, items: [ExtensionItem], command: String?) {
        self.kind = kind
        self.name = name
        self.items = items
        self.command = command
    }

    public var id: String { name }
    /// The items with an update.
    public var outdated: [ExtensionItem] { items.filter { $0.state == .updateAvailable } }
    public var updates: Int { outdated.count }
    public var moved: Int { items.filter { $0.state == .moved }.count }
    /// The items whose state could not be told.
    public var unknown: Int { items.filter { Self.reason(of: $0) != nil }.count }
    public var needsAttention: Bool { updates + moved + unknown > 0 }
    /// Why the first item of unknown state is so.
    public var unknownReason: UnknownReason? { items.lazy.compactMap(Self.reason).first }
    /// Whether the items were compared with their source, as opposed to the check being turned off.
    public var isChecked: Bool { items.contains { $0.state != .notChecked } }

    /// Returns why an item's state is unknown; nil when it is known or was not checked.
    /// @example reason(of: item) // .noAnswer
    private static func reason(of item: ExtensionItem) -> UnknownReason? {
        if case .unknown(let reason) = item.state { return reason }
        return nil
    }

    /// Returns the sources that need attention first, those with more updates before the others, then by name.
    /// @example ExtensionSource.inDisplayOrder(sources).first?.name // "heygen-com/hyperframes"
    public static func inDisplayOrder(_ sources: [ExtensionSource]) -> [ExtensionSource] {
        sources.sorted { left, right in
            if left.needsAttention != right.needsAttention { return left.needsAttention }
            if left.updates != right.updates { return left.updates > right.updates }
            return left.name.lowercased() < right.name.lowercased()
        }
    }
}
