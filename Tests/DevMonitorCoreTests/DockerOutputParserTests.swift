import XCTest
@testable import DevMonitorCore

final class DockerOutputParserTests: XCTestCase {
    func testContainerKeepsItsComposeProjectAndDirectory() {
        let container = DockerOutputParser.containers(from: "abc123\tshop-cache-1\tshop\t/Users/me/acme/shop\n").first
        XCTAssertEqual(container?.id, "abc123")
        XCTAssertEqual(container?.name, "shop-cache-1")
        XCTAssertEqual(container?.projectName, "shop")
        XCTAssertEqual(container?.projectRoot, "/Users/me/acme/shop")
    }

    func testContainerWithoutComposeLabelsIsSkipped() {
        XCTAssertTrue(DockerOutputParser.containers(from: "abc123\tsolo\t\t\n").isEmpty)
    }

    func testDirectoryContainingACommaIsKeptWhole() {
        let container = DockerOutputParser.containers(from: "abc123\tweb-1\tweb\t/Users/me/a,b,x=y").first
        XCTAssertEqual(container?.projectRoot, "/Users/me/a,b,x=y")
    }

    func testNamesAreCleanedBeforeTheyAreShown() {
        let container = DockerOutputParser.containers(from: "abc123\tweb\u{202E}-1\tweb\u{1B}\t/Users/me/web").first
        XCTAssertEqual(container?.name, "web-1")
        XCTAssertEqual(container?.projectName, "web")
    }

    func testMemoryIsReadFromTheUsageColumn() {
        let memory = DockerOutputParser.memory(from: "abc123\t45.5MiB / 7.6GiB\ndef456\t1.2GiB / 7.6GiB\n")
        XCTAssertEqual(memory["abc123"], 47_710_208)
        XCTAssertEqual(memory["def456"], 1_288_490_188)
    }

    func testImpossibleSizesCountAsZeroInsteadOfCrashing() {
        let memory = DockerOutputParser.memory(from: "a\tnanB / 1GiB\nb\tinfB / 1GiB\nc\t-5MiB / 1GiB\nd\t1e30GiB / 1GiB")
        XCTAssertEqual(memory, ["a": 0, "b": 0, "c": 0, "d": 0])
    }
}
