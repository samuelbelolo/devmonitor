import Foundation

/// Reads the timestamps tools write in their JSON files.
public enum Timestamp {
    /// Returns the date of a timestamp such as `2026-10-05T15:32:58.748Z`, with or without fractions of a second;
    /// nil when the text is not one.
    /// @example Timestamp.date("2026-10-05T15:32:58.748Z") // 2026-10-05 15:32:58 +0000
    public static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
}
