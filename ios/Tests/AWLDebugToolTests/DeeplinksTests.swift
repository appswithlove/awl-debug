import XCTest
@testable import AWLDebugTool

final class DeeplinksTests: XCTestCase {

    func testURLsWithSchemeAreValid() {
        XCTAssertEqual(DeeplinksManager.validURL(from: "myapp://path?id=1")?.absoluteString, "myapp://path?id=1")
        XCTAssertEqual(DeeplinksManager.validURL(from: "  https://example.com/a \n")?.absoluteString, "https://example.com/a")
    }

    func testTextWithoutSchemeIsInvalid() {
        XCTAssertNil(DeeplinksManager.validURL(from: ""))
        XCTAssertNil(DeeplinksManager.validURL(from: "path/only"))
        XCTAssertNil(DeeplinksManager.validURL(from: "not a link"))
        XCTAssertNil(DeeplinksManager.validURL(from: "://missing"))
    }
}
