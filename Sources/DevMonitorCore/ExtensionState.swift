/// Whether an installed skill or plugin matches what its source publishes now.
public enum ExtensionState: Sendable, Equatable {
    case upToDate
    case updateAvailable
    /// Skills only: the folder recorded at install time no longer exists upstream.
    case moved
    /// The check for new versions is turned off, so nothing was compared.
    case notChecked
    case unknown(UnknownReason)
}
