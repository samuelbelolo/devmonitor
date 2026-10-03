import Foundation

/// Short labels for sizes and durations, in the interface language.
public enum DisplayFormat {
    /// Returns a memory size in megabytes, or in gigabytes with one decimal from 1000 MB.
    /// @example DisplayFormat.memory(2_362_232_012, language: .french) // "2,2 Go"
    public static func memory(_ bytes: UInt64, language: AppLanguage = .current) -> String {
        let megabytes = Double(bytes) / 1_048_576
        let french = language == .french
        if megabytes < 1000 { return "\(Int(megabytes.rounded())) \(french ? "Mo" : "MB")" }
        let gigabytes = String(format: "%.1f", megabytes / 1024)
        return french ? gigabytes.replacingOccurrences(of: ".", with: ",") + " Go" : gigabytes + " GB"
    }

    /// Returns a duration in its largest unit among minutes, hours and days.
    /// @example DisplayFormat.duration(seconds: 49_200, language: .english) // "13 h"
    public static func duration(seconds: Int, language: AppLanguage = .current) -> String {
        if seconds >= 86_400 { return "\(seconds / 86_400) \(language == .french ? "j" : "d")" }
        if seconds >= 3_600 { return "\(seconds / 3_600) h" }
        return "\(max(seconds / 60, 1)) min"
    }
}
