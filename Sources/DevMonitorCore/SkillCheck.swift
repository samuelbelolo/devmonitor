import Foundation

/// Compares an installed skill with its repository, the way `skills update` does.
public enum SkillCheck {
    /// Returns the state of a skill given the current tree of its repository; `tree` is nil when GitHub did not
    /// answer, which reads as `.unknown(.noAnswer)`.
    /// @example SkillCheck.state(of: skill, in: tree) // .updateAvailable
    public static func state(of skill: InstalledSkill, in tree: RepoTree?) -> ExtensionState {
        guard let hash = skill.folderHash, let path = skill.skillPath else { return .unknown(.untracked) }
        guard skill.gitHubSource != nil else { return .unknown(.notGitHub) }
        guard let tree else { return .unknown(.noAnswer) }
        // A list cut short still gives valid hashes for the folders it shows; only an absent folder is in doubt.
        guard let latest = tree.folderSHA((path as NSString).deletingLastPathComponent) else {
            return tree.isTruncated ? .unknown(.noAnswer) : .moved
        }
        return latest == hash ? .upToDate : .updateAvailable
    }
}
