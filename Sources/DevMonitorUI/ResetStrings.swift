import DevMonitorCore
import Foundation

/// The words of the free resets: the ticket beside a gauge, the confirmation, and what a spend gave.
enum ResetStrings {
    private static let french = AppLanguage.current == .french
    private static let locale = Locale(identifier: french ? "fr_FR" : "en_US")

    static let confirmTitle = french ? "Utiliser un reset ?" : "Use a reset?"
    static let cancel = french ? "Annuler" : "Cancel"
    static let confirm = french ? "Utiliser" : "Use"
    static let spending = french ? "Utilisation du reset…" : "Using the reset…"
    static let dismiss = "OK"
    static let littleUsed = french ? "Presque rien n'y est utilisé : ce reset te rendrait très peu." : "Little of it is used: this reset would give back very little."

    static func ticketHelp(_ count: Int) -> String {
        french ? "\(count) reset\(count > 1 ? "s" : "") disponible\(count > 1 ? "s" : "") : clique pour en utiliser un"
            : "\(count) reset\(count > 1 ? "s" : "") available: click to use one"
    }

    /// Says what a reset starts again: these limits with their share, every limit, or one DevMonitor does not show.
    static func clears(_ limits: [AccountLimit], everything: Bool) -> String {
        if everything { return french ? "Toutes les limites du compte seront réinitialisées." : "Every limit of the account starts again." }
        let names = limits.map { "\(UsageStrings.name(of: $0.kind)) (\(Int($0.percentUsed.rounded())) %)" }
        switch names.count {
        case 0: return french ? "Une limite que DevMonitor n'affiche pas sera réinitialisée." : "A limit DevMonitor does not show starts again."
        case 1: return french ? "La limite \(names[0]) sera réinitialisée." : "\(names[0]) starts again."
        default:
            let list = names.dropLast().joined(separator: ", ") + (french ? " et " : " and ") + names.last!
            return french ? "Les limites \(list) seront réinitialisées." : "\(list) start again."
        }
    }

    static func left(after count: Int) -> String {
        switch count {
        case ...0: french ? "Ce sera ton dernier reset ici." : "It is your last reset here."
        default: french ? "Il t'en restera \(count)." : "You will have \(count) left."
        }
    }

    static func endsOn(_ date: Date) -> String {
        let day = date.formatted(Date.FormatStyle(locale: locale).day().month(.wide))
        return french ? "Ce reset expire le \(day)." : "This reset expires on \(day)."
    }

    /// Says the provider refused a reset, with its HTTP status and its own words when it gave them.
    static func refused(status: Int?, reason: String?) -> String {
        let code = status.map { " (\($0))" } ?? ""
        let words = reason ?? (french ? "il n'a pas été utilisé" : "it was not used")
        return french ? "Reset refusé\(code) : \(words)." : "Reset refused\(code): \(words)."
    }

    static func outcome(_ outcome: ResetSpendOutcome) -> String {
        switch outcome {
        case .spent: french ? "Reset utilisé : la limite a été réinitialisée." : "Reset used: the limit starts again."
        case .nothingToReset: french ? "Rien n'avait besoin d'être réinitialisé : le reset n'a pas été utilisé." : "Nothing needed a reset: the reset was kept."
        case .noneLeft: french ? "Il n'y a plus de reset sur ce compte." : "There is no reset left on this account."
        case .refused(let status, let reason):
            refused(status: status, reason: reason)
        case .unknown: french ? "Pas de réponse claire : le compte est relu pour savoir si le reset a servi." : "No clear answer: the account is read again to learn whether the reset was used."
        case .needsSignIn: french ? "La connexion a pris fin : reconnecte le compte." : "The sign-in has ended: connect the account again."
        }
    }
}
