import Foundation

/// The agent binaries an editor extension ships: each installed version of the extension carries its own copy.
public enum EditorExtension {
    /// Whether a binary comes from an editor extension.
    /// @example EditorExtension.contains("/Users/me/.cursor/extensions/anthropic.claude-code-2.1.287-darwin-arm64/resources/native-binary/claude") // true
    public static func contains(_ executablePath: String) -> Bool {
        executablePath.contains("/extensions/")
    }

    /// Returns the newest installed version of the extension a binary comes from; nil when it comes from none or
    /// its folder cannot be read. Restarting a session of that extension loads this version.
    /// @example EditorExtension.newestVersion(of: binaryIn2_1_287)?.text // "2.1.288"
    public static func newestVersion(of executablePath: String, listing: (String) -> [String] = directoryListing) -> VersionNumber? {
        guard let marker = executablePath.range(of: "/extensions/", options: .backwards) else { return nil }
        let directory = String(executablePath[..<marker.lowerBound]) + "/extensions"
        let folder = executablePath[marker.upperBound...].split(separator: "/").first.map(String.init) ?? ""
        guard let version = folder.range(of: #"-\d+(\.\d+)+"#, options: .regularExpression) else { return nil }
        let prefix = String(folder[..<version.lowerBound]) + "-"
        return listing(directory)
            .filter { $0.hasPrefix(prefix) && $0.dropFirst(prefix.count).first?.isNumber == true }
            .compactMap { VersionNumber(parsing: String($0.dropFirst(prefix.count))) }
            .max()
    }

    /// Returns the names in a folder, or none when it cannot be read.
    /// @example EditorExtension.directoryListing("/Users/me/.cursor/extensions").count // 42
    public static func directoryListing(_ path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }
}
