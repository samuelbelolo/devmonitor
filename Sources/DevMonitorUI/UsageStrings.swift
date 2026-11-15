import DevMonitorCore
import Foundation

/// The words of the accounts window and its menu bar item, in French or English.
enum UsageStrings {
    private static let french = AppLanguage.current == .french
    private static let locale = Locale(identifier: french ? "fr_FR" : "en_US")

    static let quotasEntry = french ? "Quotas Claude et Codex" : "Claude and Codex quotas"
    static let quotas = "Quotas"
    static let emptyPitch = french
        ? "Vois d'un coup d'œil où en sont les quotas de chacun de tes comptes, et quand ils seront réinitialisés."
        : "See at a glance where the quotas of each of your accounts stand, and when they start again."
    static let connect = french ? "Connecter" : "Sign in"
    static let name = french ? "Nom" : "Name"
    static let emptyFinePrint = french
        ? "Tu autorises DevMonitor dans ton navigateur. Il lit alors l'usage du compte, et n'utilise un reset que quand tu le confirmes. Il garde cet accès dans ton Trousseau."
        : "You allow DevMonitor in your browser. It then reads the account's usage, and uses a reset only when you confirm it. It keeps that access in your keychain."
    static let signInToAnAccount = french ? "Connecter un compte" : "Sign in to an account"
    static let readNow = french ? "Relire tous les comptes maintenant" : "Read every account now"

    /// Returns the share of a limit already used, said as such: the gauge fills as the account is used.
    /// @example UsageStrings.used(15) // "15 % used"
    static func used(_ percent: Int) -> String {
        french ? "\(percent)\u{00A0}% utilisé\(percent > 1 ? "s" : "")" : "\(percent)\u{00A0}% used"
    }
    static let waitingForBrowser = french ? "Autorise DevMonitor dans ton navigateur…" : "Allow DevMonitor in your browser…"
    static let add = french ? "Ajouter" : "Add"
    static let cancel = french ? "Annuler" : "Cancel"
    static let close = french ? "Fermer" : "Close"
    static let replacesFollowed = french ? "Ce compte est déjà suivi. Ce nouvel accès remplacera l'ancien." : "This account is already followed. This new access will replace the old one."
    static let notKept = french ? "Le Trousseau n'a pas enregistré l'accès, donc rien n'a changé. Réessaie." : "The keychain did not save the access, so nothing changed. Try again."
    static let notReadYet = french ? "Pas encore lu." : "Not read yet."
    static let signInAgain = french ? "Reconnecter" : "Sign in again"
    static let signInEnded = french ? "L'accès à ce compte a expiré." : "Access to this account has expired."
    static let unreachable = french ? "Lecture impossible pour l'instant." : "Could not read it right now."
    static let rename = french ? "Renommer" : "Rename"
    static let remove = french ? "Retirer" : "Remove"
    static let week = french ? "Semaine" : "Week"
    static let fiveHours = french ? "5\u{00A0}heures" : "5\u{00A0}hours"

    /// Returns the line that names the account a sign-in reads.
    /// @example UsageStrings.signedIn("dev@example.com") // "Allowed: dev@example.com"
    static func signedIn(_ email: String) -> String {
        french ? "Compte autorisé\u{00A0}: \(email)" : "Allowed: \(email)"
    }

    /// Returns the name of a provider as the window shows it.
    /// @example UsageStrings.name(of: .codex) // "Codex"
    static func name(of provider: Provider) -> String {
        switch provider {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    /// Returns the item of the + menu that signs in to an account of this provider.
    /// @example UsageStrings.signIn(to: .codex) // "Codex account"
    static func signIn(to provider: Provider) -> String {
        french ? "Compte \(name(of: provider))" : "\(name(of: provider)) account"
    }

    /// Returns why a sign-in to a provider's account did not go through.
    /// @example UsageStrings.failure(SignInFlow.Failure.noAnswer, provider: .claude) // "No authorization came back within 5 minutes. Try again."
    static func failure(_ error: Error, provider: Provider) -> String {
        let company = provider == .claude ? "Anthropic" : "OpenAI"
        return switch error as? SignInFlow.Failure {
        case .noAnswer: french ? "Aucune autorisation reçue en 5\u{00A0}minutes. Réessaie." : "No authorization came back within 5 minutes. Try again."
        case .stateMismatch: french ? "L'autorisation reçue ne correspond pas à cette demande. Réessaie." : "The authorization received does not match this request. Try again."
        case .refused(let status): french ? "\(company) a refusé l'autorisation (\(status))." : "\(company) refused the authorization (\(status))."
        case .unreachable: french ? "\(company) ne répond pas. Vérifie ta connexion internet, puis réessaie." : "\(company) does not answer. Check your internet connection, then try again."
        case .unreadableAnswer: french ? "La réponse d'\(company) est illisible. Réessaie plus tard." : "\(company)'s answer could not be read. Try again later."
        case .portTaken: french ? "Le port de connexion de Codex est déjà pris, sans doute par une commande codex login en cours. Termine-la, puis réessaie." : "Codex's sign-in port is already taken, likely by a codex login under way. Finish it, then try again."
        case nil: french ? "L'autorisation n'a pas pu démarrer. Réessaie." : "The authorization could not start. Try again."
        }
    }

    /// Returns the name of a limit.
    /// @example UsageStrings.name(of: .weekOnModel("Fable")) // "Fable"
    static func name(of kind: AccountLimit.Kind) -> String {
        switch kind {
        case .week: week
        case .weekOnModel(let model): model
        case .fiveHours: fiveHours
        case .window(let seconds): window(seconds)
        case .other(let name): name
        }
    }

    /// Returns the name of a window by its length: a day, a month, or else its hours.
    /// @example UsageStrings.window(86_400) // "Day"
    static func window(_ seconds: Int) -> String {
        func near(_ target: Double) -> Bool { abs(Double(seconds) - target) <= target * 0.05 }
        if near(86_400) { return french ? "Jour" : "Day" }
        if near(30 * 86_400) { return french ? "Mois" : "Month" }
        return "\(Int((Double(seconds) / 3600).rounded()))\u{00A0}h"
    }

    static func inUse(_ sessions: Int) -> String {
        let noun = sessions > 1 ? "sessions" : "session"
        return french ? "en cours · \(sessions)\u{00A0}\(noun)" : "in use · \(sessions)\u{00A0}\(noun)"
    }

    /// Returns how long until a limit starts again.
    /// @example UsageStrings.resetsIn(394_380) // "resets in 4 d 13 h"
    static func resetsIn(_ seconds: Int) -> String {
        french ? "reset dans \(countdown(seconds))" : "resets in \(countdown(seconds))"
    }

    /// Returns a wait in its two largest units: days and hours, hours and minutes, or minutes.
    /// @example UsageStrings.countdown(7_800) // "2 h 10 min"
    static func countdown(_ seconds: Int) -> String {
        let left = max(seconds, 0)
        let days = left / 86_400, hours = left % 86_400 / 3600, minutes = left % 3600 / 60
        if days > 0 { return hours > 0 ? "\(days)\u{00A0}\(french ? "j" : "d")\u{00A0}\(hours)\u{00A0}h" : "\(days)\u{00A0}\(french ? "j" : "d")" }
        if hours > 0 { return minutes > 0 ? (french ? "\(hours)\u{00A0}h\u{00A0}\(minutes)" : "\(hours)\u{00A0}h\u{00A0}\(minutes)\u{00A0}min") : "\(hours)\u{00A0}h" }
        return "\(max(minutes, 1)) min"
    }

    /// Returns how long ago the account was read.
    /// @example UsageStrings.readAgo("3 min") // "read 3 min ago"
    static func readAgo(_ duration: String) -> String {
        french ? "lu il y a \(duration)" : "read \(duration) ago"
    }

    /// Returns until when Anthropic asked to wait before reading again.
    /// @example UsageStrings.throttled(until: date) // "Anthropic asked to wait until 4:40 PM."
    static func throttled(until date: Date) -> String {
        let time = date.formatted(.dateTime.hour().minute().locale(locale))
        return french ? "Anthropic demande d'attendre jusqu'à \(time)." : "Anthropic asked to wait until \(time)."
    }

    /// Returns the day the sign-in ends, said ahead of time.
    /// @example UsageStrings.signInEnds(date) // "Access to this account expires December 13."
    static func signInEnds(_ date: Date) -> String {
        let day = date.formatted(.dateTime.day().month(.wide).locale(locale))
        return french ? "L'accès à ce compte expire le \(day)." : "Access to this account expires \(day)."
    }
}
