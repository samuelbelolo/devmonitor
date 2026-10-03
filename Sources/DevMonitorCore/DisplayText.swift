import Foundation

/// Makes text that comes from outside the app (a command line, a folder, a manifest, a container) safe to show.
public enum DisplayText {
    /// Returns the text on one line, without control or text-direction characters, cut to a length with an ellipsis.
    /// @example DisplayText.clean("pnpm dev\nINJECTED") // "pnpm dev INJECTED"
    public static func clean(_ text: String, limit: Int = 60) -> String {
        let scalars = text.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            if scalar == "\n" || scalar == "\r" || scalar == "\t" { return " " }
            switch scalar.properties.generalCategory {
            case .control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .surrogate, .unassigned: return nil
            default: return scalar
            }
        }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        let cleaned = String(view)
        return cleaned.count > limit ? String(cleaned.prefix(limit - 1)) + "…" : cleaned
    }
}
