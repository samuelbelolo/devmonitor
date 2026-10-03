import Foundation

/// The language of the interface: French on a Mac set to French, English everywhere else.
public enum AppLanguage: Sendable {
    case english
    case french

    /// The language for this Mac, from the user's preferred languages.
    public static let current = preferred(among: Locale.preferredLanguages)

    /// Returns French when the first preferred language is French, English otherwise.
    /// @example AppLanguage.preferred(among: ["fr-FR", "en-US"]) // .french
    public static func preferred(among identifiers: [String]) -> AppLanguage {
        identifiers.first?.lowercased().hasPrefix("fr") == true ? .french : .english
    }
}
