import XCTest
@testable import AWLDebugTool

/// A small auth store like an app would have, driven through the provider the way the panel drives it.
private actor FakeAuth {
    var token: String?
    var loginCount = 0

    func set(_ value: String?) { token = value }
    func login() { loginCount += 1; token = "access-token-\(loginCount)" }
}

private struct ActionError: LocalizedError {
    var errorDescription: String? { "backend down" }
}

@MainActor
final class SessionTokensTests: XCTestCase {

    private func makeProvider(_ auth: FakeAuth, withSetToken: Bool = true) -> AWLTokenProvider {
        AWLTokenProvider(label: "Access Token",
                         token: { await auth.token },
                         pollInterval: .milliseconds(10),
                         setToken: withSetToken ? { await auth.set($0) } : nil,
                         login: { await auth.login() },
                         logout: { await auth.set(nil) })
    }

    /// Waits until the entry shows `expected`, following the provider's stream like the open panel does.
    private func waitForToken(_ entry: SessionEntry, _ expected: String?, file: StaticString = #filePath, line: UInt = #line) async {
        let observing = Task { await entry.observe() }
        defer { observing.cancel() }
        for _ in 0..<200 where entry.token != expected {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(entry.token, expected, file: file, line: line)
    }

    func testTokensAreMasked() {
        XCTAssertEqual(SessionEntry.masked("eyJhbGciOiJIUzI1NiJ9.payload.sig4"), "eyJhbG…sig4")
        XCTAssertEqual(SessionEntry.masked("short"), "•••••")
    }

    func testLoginShowsUpWithoutReopening() async {
        let auth = FakeAuth()
        let entry = SessionEntry(provider: makeProvider(auth))
        await waitForToken(entry, nil)
        XCTAssertTrue(entry.canLogin)
        XCTAssertFalse(entry.canLogout)

        await entry.login()
        await waitForToken(entry, "access-token-1")
        XCTAssertTrue(entry.isLoggedIn)
        XCTAssertTrue(entry.canLogout)
        XCTAssertFalse(entry.canLogin)
    }

    func testEditWithEmptyValueDeletesTheToken() async {
        let auth = FakeAuth()
        await auth.set("old-token-value")
        let entry = SessionEntry(provider: makeProvider(auth))

        await entry.edit("  new-token-value ")
        let edited = await auth.token
        XCTAssertEqual(edited, "new-token-value")

        await entry.edit("")
        let deleted = await auth.token
        XCTAssertNil(deleted)
        await waitForToken(entry, nil)
        XCTAssertFalse(entry.isLoggedIn)
    }

    func testInvalidateWritesAnInvalidVariantThroughSetToken() async {
        let auth = FakeAuth()
        await auth.set("valid-token-value")
        let entry = SessionEntry(provider: makeProvider(auth))
        await waitForToken(entry, "valid-token-value")

        await entry.invalidateToken()
        let invalidated = await auth.token
        XCTAssertEqual(invalidated, "valid-token-value.invalid")
    }

    func testProviderWithoutSetTokenHidesEditAndDelete() async {
        let auth = FakeAuth()
        await auth.set("valid-token-value")
        let entry = SessionEntry(provider: makeProvider(auth, withSetToken: false))
        await waitForToken(entry, "valid-token-value")

        XCTAssertFalse(entry.canEdit)
        XCTAssertFalse(entry.canDelete)
        XCTAssertFalse(entry.canInvalidate)
        XCTAssertFalse(entry.canRefresh)
    }

    func testFailedActionShowsTheErrorAndUnlocksTheButtons() async {
        let entry = SessionEntry(provider: AWLTokenProvider(label: "Access Token", token: { "token" },
                                                            refresh: { throw ActionError() }))
        await entry.refresh()
        XCTAssertEqual(entry.errorMessage, "Action failed: backend down")
        XCTAssertNil(entry.runningAction)
    }

    @available(*, deprecated)
    func testDeprecatedTokenModelStillInvalidatesThroughTheApp() async {
        let model = AWLDebugTool.TokenDebugModel(label: "Refresh Token", getToken: { "refresh-123" })
        let entry = SessionEntry(provider: model.provider)
        await waitForToken(entry, "refresh-123")
        XCTAssertTrue(entry.canInvalidate)
        XCTAssertFalse(entry.canEdit)

        await entry.invalidateToken()
        XCTAssertEqual(model.invalidatedIfNeeded(token: "refresh-123", invalidate: { "invalid_" + $0 }), "invalid_refresh-123")
    }
}
