import XCTest
@testable import AWLDebugTool

@MainActor
final class SessionTokensTests: XCTestCase {

    func testTokensAreMasked() {
        XCTAssertEqual(AWLDebugTool.TokenDebugModel.masked("eyJhbGciOiJIUzI1NiJ9.payload.sig4"), "eyJhbG…sig4")
        XCTAssertEqual(AWLDebugTool.TokenDebugModel.masked("short"), "•••••")
    }

    func testAsyncProviderIsReadAgainOnEveryRefresh() async {
        var current: String? = "first"
        let model = AWLDebugTool.TokenDebugModel(label: "Access Token", token: {
            try? await Task.sleep(nanoseconds: 1_000_000)
            return current
        })

        await model.refresh()
        XCTAssertEqual(model.token, "first")

        current = "second"
        await model.refresh()
        XCTAssertEqual(model.token, "second")

        current = nil
        await model.refresh()
        XCTAssertNil(model.token)
    }

    func testSynchronousGetterStillWorks() async {
        let model = AWLDebugTool.TokenDebugModel(label: "Refresh Token", getToken: { "refresh-123" })
        await model.refresh()
        XCTAssertEqual(model.token, "refresh-123")
    }
}
