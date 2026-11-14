import DevMonitorCore
import Foundation

/// The words of the accounts window and its menu bar item, in French or English.
enum UsageStrings {
    private static let french = AppLanguage.current == .french
    private static let locale = Locale(identifier: french ? "fr_FR" : "en_US")

    static let withRoom = french ? "comptes Claude avec de la marge" : "Claude accounts with room"
    static let signInToAnAccount = french ? "Connecter un compte" : "Sign in to an account"
    static let noAccount = french ? "Aucun compte suivi. Clique sur + pour en connecter un." : "No account followed yet. Click + to sign in to one."
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

    /// Returns why a sign-in did not go through.
    /// @example UsageStrings.failure(ClaudeSignInFlow.Failure.noAnswer) // "The browser did not come back in time."
    static func failure(_ error: Error) -> String {
        switch error as? ClaudeSignInFlow.Failure {
        case .noAnswer: french ? "Le navigateur n'est pas revenu à temps." : "The browser did not come back in time."
        case .stateMismatch: french ? "La réponse du navigateur n'était pas celle de cette connexion." : "The browser's answer was not this sign-in's."
        case .refused(let status): french ? "Anthropic a refusé la connexion (\(status))." : "Anthropic refused the sign-in (\(status))."
        case .unreachable: french ? "Anthropic est injoignable." : "Anthropic cannot be reached."
        case .unreadableAnswer: french ? "La réponse d'Anthropic est illisible." : "Anthropic's answer could not be read."
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
        case .other(let name): name
        }
    }

    /// Returns when a limit starts again: its weekday and time.
    /// @example UsageStrings.resets(friday) // "resets Fri 5:00 AM"
    static func resets(_ date: Date) -> String {
        let when = date.formatted(.dateTime.weekday(.abbreviated).hour().minute().locale(locale))
        return french ? "repart \(when)" : "resets \(when)"
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
