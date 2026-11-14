import Foundation

/// Compares an installed skill with its repository, the way `skills update` does.
public enum SkillCheck {
    /// Returns the state of a skill given the last tree GitHub gave of its repository; `tree` is nil when GitHub
    /// never answered, which reads as `.unknown(.noAnswer)`. A skill installed or updated after that tree was last
    /// checked reads as up to date: the tree is older than the skill, so it cannot call it outdated.
    /// @example SkillCheck.state(of: skill, in: tree) // .updateAvailable
    public static func state(of skill: InstalledSkill, in tree: RepoTree?) -> ExtensionState {
        guard let hash = skill.folderHash, let path = skill.skillPath else { return .unknown(.untracked) }
        guard skill.gitHubSource != nil else { return .unknown(.notGitHub) }
        guard let tree else { return .unknown(.noAnswer) }
        // The tool installs a skill as its repository is at that moment. A skill written after GitHub last vouched
        // for this tree is at least as new as the tree: another hash, or a folder the tree lacks, says nothing
        // until GitHub gives a tree checked after that update.
        if let updated = skill.updatedAt, let checked = tree.checkedAt, updated > checked { return .upToDate }
        // A list cut short still gives valid hashes for the folders it shows; only an absent folder is in doubt.
        guard let latest = tree.folderSHA((path as NSString).deletingLastPathComponent) else {
            return tree.isTruncated ? .unknown(.noAnswer) : .moved
        }
        return latest == hash ? .upToDate : .updateAvailable
    }
}
