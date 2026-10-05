/// One skill recorded in the lock file of the `skills` tool.
public struct InstalledSkill: Sendable, Equatable {
    public let name: String
    public let source: String?
    public let sourceType: String?
    public let ref: String?
    /// The path of the skill's `SKILL.md` in its repository.
    public let skillPath: String?
    /// The git tree hash of the skill's folder when it was installed or last updated.
    public let folderHash: String?

    public init(name: String, source: String?, sourceType: String?, ref: String?, skillPath: String?, folderHash: String?) {
        self.name = name
        self.source = source
        self.sourceType = sourceType
        self.ref = ref
        self.skillPath = skillPath
        self.folderHash = folderHash
    }

    /// The GitHub repository to compare the skill with; nil when it comes from somewhere else.
    public var gitHubSource: SkillSource? {
        guard sourceType == "github", let source else { return nil }
        return SkillSource(repo: source, ref: ref)
    }
}
