/// The two kinds of extension the window lists.
public enum ExtensionKind: Sendable, Equatable {
    /// Installed with the `skills` tool, grouped by repository, updated with one command per repository.
    case skills
    /// Installed with `claude plugin`, grouped by marketplace, updated one by one.
    case plugins
}
