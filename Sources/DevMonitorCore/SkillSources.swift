/// Groups the installed skills by the repository they come from.
public enum SkillSources {
    /// Returns one source per repository and ref, in display order; with `checksUpstream` off no skill is checked.
    /// @example SkillSources.sources(for: skills, trees: trees, checksUpstream: true).first?.updates // 8
    public static func sources(for skills: [InstalledSkill], trees: [SkillSource: RepoTree], checksUpstream: Bool) -> [ExtensionSource] {
        let groups = Dictionary(grouping: skills) { $0.gitHubSource?.name ?? $0.source ?? "?" }
        let sources = groups.map { name, members -> ExtensionSource in
            let items = members.sorted { $0.name < $1.name }.map { skill -> ExtensionItem in
                let state = checksUpstream ? state(of: skill, trees: trees) : .notChecked
                return ExtensionItem(id: "\(name) \(skill.name)", name: skill.name, detail: nil, state: state, command: nil)
            }
            let source = ExtensionSource(kind: .skills, name: name, items: items, command: nil)
            return ExtensionSource(kind: .skills, name: name, items: items, command: ExtensionCommand.updateSkills(source.outdated.map(\.name)))
        }
        return ExtensionSource.inDisplayOrder(sources)
    }

    /// Returns the state of a skill; an update whose name cannot go into a command reads as unknown, with that reason.
    /// @example state(of: skill, trees: trees) // .updateAvailable
    private static func state(of skill: InstalledSkill, trees: [SkillSource: RepoTree]) -> ExtensionState {
        let state = SkillCheck.state(of: skill, in: skill.gitHubSource.flatMap { trees[$0] })
        return state == .updateAvailable && !ExtensionCommand.isPlainWord(skill.name) ? .unknown(.unsafeName) : state
    }
}
