import Foundation

/// Creates a unique empty temporary directory and returns its resolved path.
/// @example makeTempDirectory() // "/private/var/folders/…/devmon-3F2A"
func makeTempDirectory() -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("devmon-" + UUID().uuidString).resolvingSymlinksInPath()
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.path
}

/// Creates a file and its parent directories, with the given text content.
/// @example write("/tmp/x/package.json", "{}")
func write(_ path: String, _ content: String = "") {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! content.write(to: url, atomically: true, encoding: .utf8)
}
