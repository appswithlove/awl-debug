import XCTest
@testable import AWLDebugTool

final class LogsAttachmentTests: XCTestCase {

    private static let zurich = TimeZone(identifier: "Europe/Zurich")!

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)!
    }

    /// Everything from the `filters:` line on of the golden file shared with the Android SDK.
    private static func goldenBody() throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "logs", withExtension: "txt", subdirectory: "Fixtures"))
        let text = try String(contentsOf: url, encoding: .utf8)
        return String(text[try XCTUnwrap(text.range(of: "filters:")).lowerBound...])
    }

    func testBodyMatchesGoldenFile() throws {
        let logs = [
            AppLogEntry(date: Self.date("2026-09-29T10:15:30.123+02:00"), level: .error, tag: "Auth", message: "failed",
                        errorDescription: "java.lang.IllegalStateException: x\n    at com.example.Auth.login(Auth.kt:42)"),
            AppLogEntry(date: Self.date("2026-09-29T10:15:30.456+02:00"), level: .warn, tag: nil, message: "retrying", errorDescription: nil),
        ]
        var login = NetworkLog(id: UUID(), method: "POST", url: "https://api.example.ch/v1/login",
                               date: Self.date("2026-09-29T10:15:29.001+02:00"), duration: 342, statusCode: 401)
        login.requestHeaders = [.init(name: "Content-Type", value: "application/json"), .init(name: "Authorization", value: "[REDACTED]")]
        login.responseHeaders = [.init(name: "Content-Type", value: "application/json")]
        var image = NetworkLog(id: UUID(), method: "GET", url: "https://cdn.example.ch/img/42.jpg",
                               date: Self.date("2026-09-29T10:15:29.500+02:00"), duration: 30000, statusCode: 0)
        image.errorCode = NetworkLog.errorCode(for: URLError(.timedOut))

        let body = LogsAttachment.body(logs: logs,
                                       filters: LogsAttachment.describeFilters(levels: [.warn, .error], search: "checkout"),
                                       requests: [login, image], maxBytes: LogsAttachment.bodyMaxBytes, timeZone: Self.zurich)

        XCTAssertEqual(body, try Self.goldenBody())
    }

    func testFilters() {
        XCTAssertEqual(LogsAttachment.describeFilters(levels: [], search: ""), "none")
        XCTAssertEqual(LogsAttachment.describeFilters(levels: [.debug, .info], search: #"say "hi""#), #"severity=INFO,DEBUG search="say \"hi\"""#)
    }

    func testOldestEntriesAreOmittedToFit() {
        let logs = (0..<100).map {
            AppLogEntry(date: Date(timeIntervalSince1970: 1_790_000_000 + Double($0)), level: .info, tag: "T",
                        message: "entry \($0) " + String(repeating: "x", count: 100), errorDescription: nil)
        }
        let requests = (0..<10).map {
            NetworkLog(id: UUID(), method: "GET", url: "https://api.example.ch/\($0)", date: Date(timeIntervalSince1970: 1_790_000_000),
                       duration: 1, statusCode: 200)
        }

        let body = LogsAttachment.body(logs: logs, filters: "none", requests: requests, maxBytes: 4000, timeZone: Self.zurich)

        XCTAssertLessThanOrEqual(body.utf8.count, 4000)
        XCTAssertTrue(body.contains("entry 99 "))
        XCTAssertFalse(body.contains("entry 0 "))
        XCTAssertTrue(body.contains("older entries omitted\n"))
        XCTAssertTrue(body.contains("## Network (10 of 50)\n"))
    }

    func testMultiLineMessagesAndControlCharacters() {
        let entry = AppLogEntry(date: Date(timeIntervalSince1970: 0), level: .debug, tag: " ", message: "a\r\nb\u{0}", errorDescription: "E\n\tat x\n")

        let body = LogsAttachment.body(logs: [entry], filters: "none", requests: [], maxBytes: 10_000, timeZone: TimeZone(identifier: "UTC")!)

        XCTAssertTrue(body.contains("1970-01-01T00:00:00.000Z | DEBUG | - | a\n    b\u{FFFD}\n    E\n        at x\n\n## Network"), body)
    }

    func testErrorCodes() {
        XCTAssertEqual(NetworkLog.errorCode(for: URLError(.timedOut)), "timeout")
        XCTAssertEqual(NetworkLog.errorCode(for: URLError(.cannotFindHost)), "dns")
        XCTAssertEqual(NetworkLog.errorCode(for: URLError(.serverCertificateUntrusted)), "tls")
        XCTAssertEqual(NetworkLog.errorCode(for: URLError(.cancelled)), "cancelled")
        XCTAssertEqual(NetworkLog.errorCode(for: URLError(.cannotConnectToHost)), "connection")
    }

    /// Captured through the real URL protocol and fetched the way `AWLDebugFeedback` does: no secret reaches the attachment (AK-FB-8).
    @MainActor
    func testBridgeDeliversRedactedAttachment() async throws {
        let server = try LocalHTTPServer()
        defer { server.stop() }
        server.route("/login", .init(headers: [("Content-Type", "application/json"), ("Set-Cookie", "session=s3cr3t")],
                                     body: Data(#"{"access_token":"a.b.c"}"#.utf8)))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: server.url("/login?token=abc"))
        request.httpMethod = "POST"
        request.setValue("Bearer x.y.z", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(#"{"password":"hunter2"}"#.utf8)
        AWLDebugTool.log("Authorization: Bearer abc.def", tag: "Auth")
        _ = try await session.data(for: request)

        let bridge = try XCTUnwrap(NSClassFromString("AWLDebugToolBridge") as? AWLDebugToolBridge.Type)
        var text = ""
        for _ in 0..<100 where !(text.contains("/login?token=") && text.contains("Bearer [REDACTED]")) {
            let data: Data? = await withCheckedContinuation { continuation in
                bridge.feedbackLogsAttachment { continuation.resume(returning: $0) }
            }
            text = String(decoding: data ?? Data(), as: UTF8.self)
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertTrue(text.hasPrefix("filters: "), text)
        XCTAssertTrue(text.contains(" POST 200 "), text)
        XCTAssertTrue(text.contains("| INFO | Auth | Authorization: Bearer [REDACTED]\n"), text)
        XCTAssertTrue(text.contains("    > authorization: [REDACTED]\n"), text)
        XCTAssertTrue(text.contains("    < set-cookie: [REDACTED]\n"), text)
        for secret in ["x.y.z", "abc.def", "s3cr3t", "token=abc", "hunter2", "a.b.c"] {
            XCTAssertFalse(text.contains(secret), "\(secret) leaked into \(text)")
        }
    }
}
