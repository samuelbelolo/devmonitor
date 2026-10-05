import DevMonitorCore
import Foundation

/// Every sentence and label of the interface, in French or English. Sizes and durations come from `DisplayFormat`.
enum Strings {
    private static let french = AppLanguage.current == .french

    static let stop = french ? "Arrêter" : "Stop"
    static let confirm = french ? "Confirmer" : "Confirm"
    static let force = french ? "Forcer" : "Force quit"
    static let orphan = french ? "orphelin" : "orphan"
    static let nothingRunning = french ? "Rien ne tourne." : "Nothing is running."
    static let launchAtLogin = french ? "Lancer à l'ouverture de session" : "Launch at login"
    static let quit = french ? "Quitter" : "Quit"
    static let mcpServers = french ? "Serveurs MCP" : "MCP servers"

    /// Returns the caption next to the total, with the number of projects.
    /// @example Strings.usedBy(projects: 4) // "used by 4 projects"
    static func usedBy(projects count: Int) -> String {
        french ? "utilisés par \(count) projet\(count > 1 ? "s" : "")" : "used by \(count) project\(count > 1 ? "s" : "")"
    }

    /// Returns a count of processes.
    /// @example Strings.processes(3) // "3 processes"
    static func processes(_ count: Int) -> String {
        french ? "\(count) process" : "\(count) process\(count > 1 ? "es" : "")"
    }

    /// Returns a count of containers.
    /// @example Strings.containers(6) // "6 containers"
    static func containers(_ count: Int) -> String {
        french ? "\(count) conteneur\(count > 1 ? "s" : "")" : "\(count) container\(count > 1 ? "s" : "")"
    }

    /// Returns the tag of a service that has done nothing for a duration.
    /// @example Strings.idle(for: "13 h") // "idle 13 h"
    static func idle(for duration: String) -> String {
        french ? "au repos \(duration)" : "idle \(duration)"
    }

    /// Returns the caption naming the agent that started a service.
    /// @example Strings.startedBy("Claude") // "started by Claude"
    static func startedBy(_ agent: String) -> String {
        french ? "lancé par \(agent)" : "started by \(agent)"
    }

    /// Returns the title of the button that stops every idle service, with the memory it frees.
    /// @example Strings.stopIdle(count: 3, memory: "416 MB") // "Stop 3 idle · frees 416 MB"
    static func stopIdle(count: Int, memory: String) -> String {
        french ? "Arrêter \(count) au repos · libère \(memory)" : "Stop \(count) idle · frees \(memory)"
    }

    static let byProject = french ? "Par projet" : "By project"
    static let versions = "Versions"
    static let outsideProjects = french ? "Hors projet" : "Outside any project"
    static let working = french ? "travaille" : "working"
    static let waiting = french ? "attend" : "waiting"
    static let upToDate = french ? "à jour" : "up to date"
    static let versionUnreadable = french ? "version illisible" : "version unreadable"
    static let latestUnknown = french ? "dernière version inconnue" : "latest version unknown"
    static let copy = french ? "Copier" : "Copy"
    static let copied = french ? "Copié" : "Copied"
    static let noAgent = french ? "Aucun agent installé." : "No coding agent installed."
    static let checkVersions = french ? "Vérifier les nouvelles versions" : "Check for new versions"
    static let animateLogo = french ? "Animer le logo quand un agent travaille" : "Animate the logo while an agent works"

    /// Returns the caption next to the number of sessions.
    /// @example Strings.sessionsCaption(working: 3) // "agent sessions · 3 working"
    static func sessionsCaption(working: Int) -> String {
        let busy = working == 0
            ? (french ? "toutes en attente" : "all waiting")
            : (french ? "\(working) travaille\(working > 1 ? "nt" : "")" : "\(working) working")
        return (french ? "sessions d'agent · " : "agent sessions · ") + busy
    }

    /// Returns the count of open sessions of one agent.
    /// @example Strings.openSessions(8) // "8 open sessions"
    static func openSessions(_ count: Int) -> String {
        if count == 0 { return french ? "aucune session" : "no session" }
        return french ? "\(count) session\(count > 1 ? "s" : "") ouverte\(count > 1 ? "s" : "")" : "\(count) open session\(count > 1 ? "s" : "")"
    }

    /// Names a session: its agent, and the agent that started it, if any.
    /// @example Strings.session(of: .codex, launchedBy: .claude) // "Codex, launched by Claude"
    static func session(of agent: Agent, launchedBy launcher: Agent?) -> String {
        guard let launcher else { return agent.displayName }
        return french ? "\(agent.displayName), lancée par \(launcher.displayName)" : "\(agent.displayName), launched by \(launcher.displayName)"
    }

    /// Returns how many of an agent's sessions another agent started, e.g. Claude running Codex for a review.
    /// @example Strings.launchedBy(1, "Claude") // "1 launched by Claude"
    static func launchedBy(_ count: Int, _ agent: String) -> String {
        french ? "\(count) lancée\(count > 1 ? "s" : "") par \(agent)" : "\(count) launched by \(agent)"
    }

    /// Returns the tag of an agent with a newer version published.
    /// @example Strings.available("2.1.291") // "2.1.291 available"
    static func available(_ version: String) -> String {
        french ? "\(version) disponible" : "\(version) available"
    }

    /// Returns the note on sessions that still run an older version than the installed one.
    /// @example Strings.toRestart(1, oldest: "2.1.287") // "1 session on 2.1.287 · restart to update"
    static func toRestart(_ count: Int, oldest: String) -> String {
        french
            ? "\(count) session\(count > 1 ? "s" : "") en \(oldest) · à relancer"
            : "\(count) session\(count > 1 ? "s" : "") on \(oldest) · restart to update"
    }

    static let extensions = "Extensions"
    static let unknown = french ? "inconnu" : "unknown"

    /// Returns the title of a kind of extension.
    /// @example Strings.title(.plugins) // "Plugins"
    static func title(_ kind: ExtensionKind) -> String {
        kind == .plugins ? "Plugins" : "Skills"
    }

    /// Returns what the sources of a kind are called, for a count of them.
    /// @example Strings.sourceNoun(.plugins, count: 6) // "marketplaces"
    private static func sourceNoun(_ kind: ExtensionKind, count: Int) -> String {
        (kind == .plugins ? "marketplace" : "source") + (count > 1 ? "s" : "")
    }

    /// Returns a count of installed extensions and of their sources.
    /// @example Strings.installed(85, sources: 11, kind: .skills) // "85 · 11 sources"
    static func installed(_ count: Int, sources: Int, kind: ExtensionKind) -> String {
        "\(count) · \(sources) \(sourceNoun(kind, count: sources))"
    }

    /// Returns a count of extensions with an update.
    /// @example Strings.updates(27) // "27 updates"
    static func updates(_ count: Int) -> String {
        french ? "\(count) mise\(count > 1 ? "s" : "") à jour" : "\(count) update\(count > 1 ? "s" : "")"
    }

    /// Returns a count of skills whose folder no longer exists upstream.
    /// @example Strings.moved(18) // "18 moved"
    static func moved(_ count: Int) -> String {
        french ? "\(count) déplacé\(count > 1 ? "s" : "")" : "\(count) moved"
    }

    /// Returns when GitHub last answered about the skills.
    /// @example Strings.checked(ago: "2 h") // "checked 2 h ago"
    static func checked(ago duration: String) -> String {
        french ? "vérifié il y a \(duration)" : "checked \(duration) ago"
    }

    /// Returns up to three names, then how many more there are.
    /// @example Strings.names(["a", "b", "c", "d", "e"]) // "a, b, c and 2 more"
    static func names(_ names: [String]) -> String {
        let shown = names.prefix(3).joined(separator: ", ")
        let rest = names.count - 3
        guard rest > 0 else { return shown }
        return shown + (french ? " et \(rest) autre\(rest > 1 ? "s" : "")" : " and \(rest) more")
    }

    /// Returns the line that folds the sources with nothing to do. `others` is set when sources are listed above
    /// it, and `checked` is false when the check is turned off.
    /// @example Strings.quietSources(4, items: 23, kind: .skills, others: true, checked: true) // "4 other sources up to date · 23 skills"
    static func quietSources(_ count: Int, items: Int, kind: ExtensionKind, others: Bool, checked: Bool) -> String {
        let plural = count > 1 ? "s" : ""
        let noun = sourceNoun(kind, count: count)
        let what = "\(items) \(kind == .plugins ? "plugin" : "skill")\(items > 1 ? "s" : "")"
        let sources = french ? "\(count) \(others ? "autre\(plural) " : "")\(noun)" : "\(count) \(others ? "other " : "")\(noun)"
        if !checked { return sources + (french ? " non vérifiée\(plural) · " : " not checked · ") + what }
        return sources + (french ? " à jour · " : " up to date · ") + what
    }

    /// Returns the note on skills whose folder no longer exists in their repository.
    /// @example Strings.movedNote(18) // "18 skills are no longer at this place in the repository: renamed, merged or removed."
    static func movedNote(_ count: Int) -> String {
        french
            ? "\(count) skill\(count > 1 ? "s" : "") n'existe\(count > 1 ? "nt" : "") plus à cet endroit du dépôt : renommé\(count > 1 ? "s" : ""), fusionné\(count > 1 ? "s" : "") ou supprimé\(count > 1 ? "s" : "")."
            : "\(count) skill\(count > 1 ? "s are" : " is") no longer at this place in the repository: renamed, merged or removed."
    }

    /// Returns the warning on marketplaces that were not refreshed for more than seven days.
    /// @example Strings.staleCatalogs(5) // "5 catalogs are more than 7 days old: the states above may be late."
    static func staleCatalogs(_ count: Int) -> String {
        french
            ? "\(count) catalogue\(count > 1 ? "s ont" : " a") plus de 7 jours : les états ci-dessus peuvent être en retard."
            : "\(count) catalog\(count > 1 ? "s are" : " is") more than 7 days old: the states above may be late."
    }

    /// Returns why the state of a source's extensions could not be told.
    /// @example Strings.unknownReason(.notGitHub) // "The source is not a GitHub repository."
    static func unknownReason(_ reason: UnknownReason) -> String {
        switch reason {
        case .untracked: french ? "Le fichier de verrouillage ne garde ni dossier ni empreinte à comparer." : "The lock file keeps no folder or hash to compare."
        case .notGitHub: french ? "La source n'est pas un dépôt GitHub." : "The source is not a GitHub repository."
        case .noAnswer:
            french
                ? "GitHub n'a pas donné l'arbre de ce dépôt : pas de réponse, limite horaire atteinte, ou dépôt trop grand."
                : "GitHub did not give this repository's tree: no answer, hourly limit reached, or repository too large."
        case .noCatalog: french ? "Ce marketplace, ou son catalogue, est introuvable sur ce Mac." : "This marketplace, or its catalog, is not on this Mac."
        case .nothingToCompare: french ? "Rien à comparer : ni version, ni commit, ni fichiers à rapprocher." : "Nothing to compare: no version, commit or files to set side by side."
        case .unsafeName: french ? "Une mise à jour existe, mais le nom contient des caractères spéciaux : aucune commande n'est proposée." : "An update exists, but the name has special characters: no command is offered."
        }
    }
}
