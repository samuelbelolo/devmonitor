import SwiftUI

/// The colors that tell projects and states apart.
enum Palette {
    static let ok = Color(red: 0.24, green: 0.86, blue: 0.59)
    static let idle = Color(red: 0.96, green: 0.72, blue: 0.29)
    static let orphan = Color(red: 1.0, green: 0.42, blue: 0.42)
    private static let projects: [Color] = [
        Color(red: 0.49, green: 0.55, blue: 1.0), Color(red: 0.30, green: 0.79, blue: 0.94),
        Color(red: 1.0, green: 0.62, blue: 0.42), Color(red: 0.93, green: 0.47, blue: 0.80),
        Color(red: 0.55, green: 0.85, blue: 0.45), Color(red: 0.95, green: 0.82, blue: 0.35),
    ]

    /// Returns a color for a project that stays the same across refreshes.
    /// @example Palette.color(for: "/Users/me/acme/shop") // indigo
    static func color(for id: String) -> Color {
        let hash = id.utf8.reduce(5381) { ($0 &* 33) &+ Int($1) }
        return projects[Int(hash.magnitude % UInt(projects.count))]
    }
}
