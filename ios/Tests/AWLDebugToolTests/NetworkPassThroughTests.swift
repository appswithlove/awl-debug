import XCTest
@testable import AWLDebugTool

/// WebSockets, Server-Sent Events, downloads and large uploads are left to the system and logged from their metadata.
final class NetworkPassThroughTests: XCTestCase {

    private var webSocketServer: LocalWebSocketServer!
    private var server: LocalHTTPServer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        webSocketServer = try LocalWebSocketServer()
        server = try LocalHTTPServer()
    }

    override func tearDown() {
        webSocketServer.stop()
        server.stop()
        super.tearDown()
    }

    /// Like the sessions `URLSessionConfiguration.default` creates once the tool started.
    private func capturedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self] + (configuration.protocolClasses ?? [])
        return URLSession(configuration: configuration)
    }

    private func uniquePath() -> String {
        "/\(name.filter(\.isLetter))-\(UUID().uuidString)"
    }

    private func echo(_ text: String, over task: URLSessionWebSocketTask) async throws -> String? {
        try await task.send(.string(text))
        guard case .string(let reply) = try await task.receive() else { return nil }
        return reply
    }

    private func fetchLog(path: String, timeout: TimeInterval = 5) async throws -> NetworkLog {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let log = await MainActor.run {
                AWLDebugTool.shared.networkLogger.networkTraffic.last { $0.url.hasSuffix(path) }
            }
            if let log {
                return log
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "no log for \(path)"])
    }

    private func assertNoLog(path: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        let log = await MainActor.run {
            AWLDebugTool.shared.networkLogger.networkTraffic.last { $0.url.hasSuffix(path) }
        }
        XCTAssertNil(log)
    }

    // MARK: - WebSockets

    /// awl-debug 2.0.1 dropped the connection right away with -1005; the app saw it every 5 seconds when reconnecting.
    func testWebSocketStaysOpen() async throws {
        let session = capturedSession()
        defer { session.invalidateAndCancel() }
        let task = session.webSocketTask(with: webSocketServer.url(uniquePath()))
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        let first = try await echo("first", over: task)
        XCTAssertEqual(first, "first")
        try await Task.sleep(nanoseconds: 6_000_000_000)
        let second = try await echo("second", over: task)
        XCTAssertEqual(second, "second")
    }

    func testClosedWebSocketIsLoggedFromMetadata() async throws {
        let path = uniquePath()
        let session = capturedSession()
        defer { session.invalidateAndCancel() }
        let task = session.webSocketTask(with: webSocketServer.url(path))
        task.resume()
        let reply = try await echo("hello", over: task)
        XCTAssertEqual(reply, "hello")
        task.cancel(with: .normalClosure, reason: nil)

        let log = try await fetchLog(path: path)

        XCTAssertEqual(log.method, "GET")
        XCTAssertEqual(log.statusCode, 101)
        XCTAssertTrue(log.url.hasPrefix("ws://"), log.url)
        XCTAssertEqual(log.requestHeaders.first { $0.name == "Upgrade" }?.value, "websocket")
        XCTAssertNil(log.requestBody)
        XCTAssertEqual(log.responseBody?.text, "(stream, not captured)")
    }

    func testExcludedWebSocketStaysOpenAndIsNotLogged() async throws {
        let path = uniquePath()
        let session = capturedSession()
        defer { session.invalidateAndCancel() }
        let task = session.webSocketTask(with: AWLDebugExtensions.excludeFromCapture(URLRequest(url: webSocketServer.url(path))))
        task.resume()
        let reply = try await echo("hello", over: task)
        XCTAssertEqual(reply, "hello")
        task.cancel(with: .normalClosure, reason: nil)

        try await assertNoLog(path: path)
    }

    // MARK: - Streams, downloads, uploads

    func testEventStreamIsPassedThroughAndLogged() async throws {
        let path = uniquePath()
        let chunks = (0..<3).map { Data("data: \($0)\n\n".utf8) }
        server.route(path, .init(headers: [("Content-Type", "text/event-stream")], chunks: chunks, chunkInterval: 0.1))
        var request = URLRequest(url: server.url(path))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let session = capturedSession()
        defer { session.invalidateAndCancel() }

        let (data, _) = try await session.data(for: request)
        let log = try await fetchLog(path: path)

        XCTAssertEqual(data, chunks.reduce(Data(), +))
        XCTAssertEqual(log.statusCode, 200)
        XCTAssertEqual(log.responseBody?.text, "(stream, not captured)")
        XCTAssertEqual(log.responseBytes, data.count)
    }

    func testDownloadIsPassedThroughAndLoggedWithoutBody() async throws {
        let path = uniquePath()
        let body = Data(repeating: 7, count: 2 * 1024 * 1024)
        server.route(path, .init(headers: [("Content-Type", "application/zip")], body: body))
        let session = capturedSession()
        defer { session.invalidateAndCancel() }

        let (file, _) = try await session.download(from: server.url(path))
        let log = try await fetchLog(path: path)

        XCTAssertEqual(try Data(contentsOf: file), body)
        XCTAssertEqual(log.statusCode, 200)
        XCTAssertEqual(log.responseBytes, body.count)
        XCTAssertEqual(log.responseBody?.text, "(not captured)")
    }

    func testSmallUploadIsStillCaptured() async throws {
        let path = uniquePath()
        var request = URLRequest(url: server.url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Data(#"{"name":"a","password":"p"}"#.utf8)
        let session = capturedSession()
        defer { session.invalidateAndCancel() }

        _ = try await session.upload(for: request, from: body)
        let log = try await fetchLog(path: path)

        XCTAssertEqual(server.receivedBody(path), body)
        XCTAssertEqual(log.requestBody?.text, #"{"name":"a","password":"[REDACTED]"}"#)
    }

    func testLargeUploadIsPassedThroughAndLoggedWithoutBody() async throws {
        let path = uniquePath()
        var request = URLRequest(url: server.url(path))
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let body = Data(repeating: 3, count: 2 * 1024 * 1024)
        let session = capturedSession()
        defer { session.invalidateAndCancel() }

        _ = try await session.upload(for: request, from: body)
        let log = try await fetchLog(path: path)

        XCTAssertEqual(server.receivedBody(path), body)
        XCTAssertEqual(log.requestBytes, body.count)
        XCTAssertEqual(log.requestBody?.text, "(not captured)")
    }
}
