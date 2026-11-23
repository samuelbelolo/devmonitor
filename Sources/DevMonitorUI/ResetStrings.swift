import DevMonitorCore
import Foundation

/// The words of the free resets: the ticket beside a gauge, the confirmation, and what a spend gave.
enum ResetStrings {
    private static let french = AppLanguage.current == .french
    private static let locale = Locale(identifier: french ? "fr_FR" : "en_US")

    static let confirmTitle = french ? "Utiliser un reset\u{00A0}?" : "Use a reset?"
    static let cancel = french ? "Annuler" : "Cancel"
    static let confirm = french ? "Utiliser" : "Use"
    static let spending = french ? "Utilisation du reset…" : "Using the reset…"
    static let dismiss = "OK"
    /// Returns the warning shown when what a reset clears is used under this share.
    /// @example ResetStrings.littleUsed(under: 10) // "This reset would give back less than 10 %."
    static func littleUsed(under percent: Int) -> String {
        french ? "Ce reset te rendrait moins de \(percent)\u{00A0}%." : "This reset would give back less than \(percent)\u{00A0}%."
    }

    static func ticketHelp(_ count: Int) -> String {
        french ? "\(count) reset\(count > 1 ? "s" : "") disponible\(count > 1 ? "s" : ""). Clique pour en utiliser un."
            : "\(count) reset\(count > 1 ? "s" : "") available. Click to use one."
    }

    /// Says what a reset starts again: these limits with their share, every limit, or one DevMonitor does not show.
    static func clears(_ limits: [AccountLimit], everything: Bool) -> String {
        if everything { return french ? "Toutes les limites du compte seront réinitialisées." : "Every limit of the account starts again." }
        let names = limits.map { "\(UsageStrings.name(of: $0.kind)) (\(Int($0.percentUsed.rounded()))\u{00A0}%)" }
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
        case ...0: french ? "C'est ton dernier reset sur ce compte." : "It is your last reset on this account."
        default: french ? "Il t'en restera \(count)." : "You will have \(count) left."
        }
    }

    static func endsOn(_ date: Date) -> String {
        let day = date.formatted(Date.FormatStyle(locale: locale).day().month(.wide))
        return french ? "Ce reset expire le \(day)." : "This reset expires on \(day)."
    }

    /// Says the provider refused a reset, with its HTTP status and its own words when it gave them.
    /// @example ResetStrings.refused(status: 403, reason: nil) // "Reset refused (403). It was not used."
    static func refused(status: Int?, reason: String?) -> String {
        let code = status.map { " (\($0))" } ?? ""
        if let reason { return french ? "Reset refusé\(code)\u{00A0}: \(reason)." : "Reset refused\(code): \(reason)." }
        return french ? "Reset refusé\(code). Il n'a pas été utilisé." : "Reset refused\(code). It was not used."
    }

    static func outcome(_ outcome: ResetSpendOutcome) -> String {
        switch outcome {
        case .spent: french ? "Reset utilisé." : "Reset used."
        case .nothingToReset: french ? "Rien à réinitialiser. Le reset est conservé." : "Nothing to reset. The reset is kept."
        case .noneLeft: french ? "Il n'y a plus de reset sur ce compte." : "There is no reset left on this account."
        case .refused(let status, let reason):
            refused(status: status, reason: reason)
        case .unknown: french ? "Réponse incertaine. DevMonitor relit le compte pour savoir si le reset a servi." : "Unclear answer. DevMonitor reads the account again to learn whether the reset was used."
        case .needsSignIn: french ? "L'accès à ce compte a expiré. Reconnecte-le." : "Access to this account has expired. Sign in again."
        }
    }
}
