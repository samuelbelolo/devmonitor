/// Why the state of a skill or a plugin could not be told.
public enum UnknownReason: Sendable, Equatable {
    /// The lock file records no folder hash or no path for the skill.
    case untracked
    /// The skill does not come from a GitHub repository.
    case notGitHub
    /// GitHub gave no usable tree: no answer, a refusal, or a list cut short that does not show the skill's folder.
    case noAnswer
    /// The marketplace, or the plugin's entry in its catalog, is missing on disk.
    case noCatalog
    /// Nothing to compare: no version or commit recorded, or the installed files or the marketplace's copy are missing.
    case nothingToCompare
    /// An update exists, but the name is not a plain word, so no command is offered for it.
    case unsafeName
}
