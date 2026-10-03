import XCTest
@testable import DevMonitorCore

final class EditorExtensionTests: XCTestCase {
    private let binary = "/Users/me/.cursor/extensions/anthropic.claude-code-2.1.287-darwin-arm64/resources/native-binary/claude"

    func testNewestVersionOfTheSameExtensionIsFound() {
        let folders = [
            "anthropic.claude-code-2.1.286-darwin-arm64", "anthropic.claude-code-2.1.288-darwin-arm64",
            "anthropic.claude-code-insiders-9.0.0-darwin-arm64", "dbaeumer.vscode-eslint-3.0.10",
        ]
        let newest = EditorExtension.newestVersion(of: binary, listing: { $0 == "/Users/me/.cursor/extensions" ? folders : [] })
        XCTAssertEqual(newest?.text, "2.1.288")
    }

    func testBinaryOutsideAnExtensionHasNoExtensionVersion() {
        XCTAssertFalse(EditorExtension.contains("/Users/me/.local/share/claude/versions/2.1.288"))
        XCTAssertTrue(EditorExtension.contains(binary))
        XCTAssertNil(EditorExtension.newestVersion(of: "/Users/me/.local/share/claude/versions/2.1.288", listing: { _ in ["x-1.0"] }))
    }
}
