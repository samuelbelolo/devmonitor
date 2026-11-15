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
        ? "Tu l'autorises dans ton navigateur. DevMonitor s'en sert pour lire l'usage du compte, et pour utiliser un reset quand tu le confirmes. Il garde cet accès dans ton Trousseau."
        : "You allow it in your browser. DevMonitor uses it to read the account's usage, and to use a reset when you confirm it. It keeps that access in your keychain."
    static let signInToAnAccount = french ? "Connecter un compte" : "Sign in to an account"
    static let readNow = french ? "Relire tous les comptes maintenant" : "Read every account now"

    /// Returns the share of a limit already used, said as such: the gauge fills as the account is used.
    /// @example UsageStrings.used(15) // "15 % used"
    static func used(_ percent: Int) -> String {
        french ? "\(percent) % utilisé\(percent > 1 ? "s" : "")" : "\(percent) % used"
    }
    static let waitingForBrowser = french ? "Autorise DevMonitor dans ton navigateur…" : "Allow DevMonitor in your browser…"
    static let add = french ? "Ajouter" : "Add"
    static let cancel = french ? "Annuler" : "Cancel"
    static let close = french ? "Fermer" : "Close"
    static let replacesFollowed = french ? "Il remplace la connexion de ce compte déjà suivi." : "It replaces the sign-in of this account, already followed."
    static let notKept = french ? "Le Trousseau n'a pas gardé la connexion : rien n'a changé." : "The keychain did not keep the sign-in: nothing changed."
    static let notReadYet = french ? "Pas encore lu." : "Not read yet."
    static let signInAgain = french ? "Reconnecter" : "Sign in again"
    static let signInEnded = french ? "La connexion a pris fin." : "The sign-in has ended."
    static let unreachable = french ? "Lecture impossible pour l'instant." : "Could not read it right now."
    static let rename = french ? "Renommer" : "Rename"
    static let remove = french ? "Retirer" : "Remove"
    static let week = french ? "Semaine" : "Week"
    static let fiveHours = french ? "5 heures" : "5 hours"

    /// Returns the line that names the account a sign-in reads.
    /// @example UsageStrings.signedIn("dev@example.com") // "Signed in to dev@example.com"
    static func signedIn(_ email: String) -> String {
        french ? "Compte obtenu : \(email)" : "Signed in to \(email)"
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
    /// @example UsageStrings.failure(SignInFlow.Failure.noAnswer, provider: .claude) // "The browser did not come back in time."
    static func failure(_ error: Error, provider: Provider) -> String {
        let company = provider == .claude ? "Anthropic" : "OpenAI"
        return switch error as? SignInFlow.Failure {
        case .noAnswer: french ? "Le navigateur n'est pas revenu à temps." : "The browser did not come back in time."
        case .stateMismatch: french ? "La réponse du navigateur n'était pas celle de cette connexion." : "The browser's answer was not this sign-in's."
        case .refused(let status): french ? "\(company) a refusé la connexion (\(status))." : "\(company) refused the sign-in (\(status))."
        case .unreachable: french ? "\(company) est injoignable." : "\(company) cannot be reached."
        case .unreadableAnswer: french ? "La réponse de \(company) est illisible." : "\(company)'s answer could not be read."
        case .portTaken: french ? "Une autre connexion est en cours sur ce Mac : réessaie quand elle sera finie." : "Another sign-in is under way on this Mac: try again once it is done."
        case nil: french ? "La connexion n'a pas pu démarrer." : "The sign-in could not start."
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
        return "\(Int((Double(seconds) / 3600).rounded())) h"
    }

    static func inUse(_ sessions: Int) -> String {
        let noun = sessions > 1 ? "sessions" : "session"
        return french ? "en cours · \(sessions) \(noun)" : "in use · \(sessions) \(noun)"
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
        if days > 0 { return hours > 0 ? "\(days) \(french ? "j" : "d") \(hours) h" : "\(days) \(french ? "j" : "d")" }
        if hours > 0 { return minutes > 0 ? (french ? "\(hours) h \(minutes)" : "\(hours) h \(minutes) min") : "\(hours) h" }
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
    /// @example UsageStrings.signInEnds(date) // "The sign-in ends December 13."
    static func signInEnds(_ date: Date) -> String {
        let day = date.formatted(.dateTime.day().month(.wide).locale(locale))
        return french ? "La connexion prend fin le \(day)." : "The sign-in ends \(day)."
    }
}
