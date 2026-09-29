//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Foundation
import Testing

/// The stub answers in-process, so the suite runs serialized.
@Suite(.serialized)
final class FeedbackQueueTests {
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "FeedbackQueueTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let clock = TestClock()
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }()

    init() {
        StubProtocol.reset()
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        StubProtocol.reset()
    }

    private func makeQueue(maxReports: Int = 20, maxBytes: Int = 50 * 1024 * 1024) -> FeedbackQueue {
        FeedbackQueue(directory: directory, session: session, now: { [clock] in clock.now },
                      maxReports: maxReports, maxBytes: maxBytes)
    }

    private func makeRequest(key: UUID = UUID(), screenshotBytes: Int = 4) throws -> URLRequest {
        let client = try FeedbackClient(endpoint: #require(URL(string: "https://feedback.example.com")), appKey: "key-123")
        let metadata = FeedbackMetadata(
            osVersion: "26.0", deviceModel: "iPhone17,1", appVersion: "1.0", buildNumber: "42",
            environment: "staging", locale: "de-CH", extraMetadata: [:], date: Date(timeIntervalSince1970: 0),
            distribution: nil, reporter: nil
        )
        return try client.makeRequest(text: "Button is cut off", metadata: metadata,
                                      screenshotJPEG: Data(repeating: 0xff, count: screenshotBytes), idempotencyKey: key)
    }

    private var queuedFolders: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
    }

    @Test
    func serviceUnavailableQueuesAndRetrySendsSameKeyAndBytes() async throws {
        let queue = makeQueue()
        let key = UUID()
        let request = try makeRequest(key: key)
        StubProtocol.statuses = [503]

        #expect(await queue.submit(request) == .queued)
        #expect(queuedFolders == [key.uuidString.lowercased()])

        StubProtocol.statuses = [201]
        await queue.retry(ignoringBackoff: true)

        #expect(StubProtocol.received.count == 2)
        let keys = StubProtocol.received.map { $0.value(forHTTPHeaderField: "Idempotency-Key") }
        #expect(keys == [key.uuidString.lowercased(), key.uuidString.lowercased()])
        #expect(StubProtocol.received.map { $0.value(forHTTPHeaderField: "X-App-Key") } == ["key-123", "key-123"])
        #expect(StubProtocol.bodies[0] == request.httpBody)
        #expect(StubProtocol.bodies[1] == request.httpBody)
        #expect(queuedFolders.isEmpty)
        #expect(await queue.pendingCount == 0)
    }

    @Test
    func offlineQueues() async throws {
        StubProtocol.failure = URLError(.notConnectedToInternet)

        #expect(try await makeQueue().submit(makeRequest()) == .queued)
        #expect(queuedFolders.count == 1)
    }

    @Test(arguments: [400, 401, 403, 413, 415, 422])
    func clientErrorsAreNotQueued(status: Int) async throws {
        StubProtocol.statuses = [status]

        let result = try await makeQueue().submit(makeRequest())

        #expect(result == .failed(FeedbackError(statusCode: status, retryAfter: nil)))
        #expect(queuedFolders.isEmpty)
    }

    @Test
    func retryWaitsForBackoff() async throws {
        let queue = makeQueue()
        StubProtocol.statuses = [503, 503, 201]
        _ = try await queue.submit(makeRequest())

        clock.advance(by: 29)
        await queue.retry(ignoringBackoff: false)
        #expect(StubProtocol.received.count == 1)

        clock.advance(by: 2)
        await queue.retry(ignoringBackoff: false)
        #expect(StubProtocol.received.count == 2)

        // The second failure doubles the backoff to 60 s.
        clock.advance(by: 59)
        await queue.retry(ignoringBackoff: false)
        #expect(StubProtocol.received.count == 2)
        clock.advance(by: 2)
        await queue.retry(ignoringBackoff: false)
        #expect(StubProtocol.received.count == 3)
        #expect(queuedFolders.isEmpty)
    }

    @Test
    func retryAfterHoldsEvenWhenIgnoringBackoff() async throws {
        let queue = makeQueue()
        StubProtocol.statuses = [429, 201]
        StubProtocol.retryAfter = "120"
        _ = try await queue.submit(makeRequest())

        clock.advance(by: 60)
        await queue.retry(ignoringBackoff: true)
        #expect(StubProtocol.received.count == 1)
        #expect(await queue.nextAttemptAt == clock.start.addingTimeInterval(120))

        clock.advance(by: 61)
        await queue.retry(ignoringBackoff: true)
        #expect(StubProtocol.received.count == 2)
        #expect(queuedFolders.isEmpty)
    }

    @Test
    func queuedReportRejectedLaterIsDropped() async throws {
        let queue = makeQueue()
        StubProtocol.statuses = [500, 401]
        _ = try await queue.submit(makeRequest())

        await queue.retry(ignoringBackoff: true)

        #expect(queuedFolders.isEmpty)
    }

    @Test
    func keepsNewestReportsWithinLimit() async throws {
        let queue = makeQueue(maxReports: 2)
        let keys = [UUID(), UUID(), UUID()]
        StubProtocol.statuses = [503, 503, 503]
        for key in keys {
            _ = try await queue.submit(makeRequest(key: key))
            clock.advance(by: 1)
        }

        #expect(queuedFolders == keys.dropFirst().map { $0.uuidString.lowercased() }.sorted())
    }

    @Test
    func keepsReportsWithinByteLimit() async throws {
        let queue = makeQueue(maxBytes: 250_000)
        let keys = [UUID(), UUID(), UUID()]
        StubProtocol.statuses = [503, 503, 503]
        for key in keys {
            _ = try await queue.submit(makeRequest(key: key, screenshotBytes: 100_000))
            clock.advance(by: 1)
        }

        #expect(queuedFolders == keys.dropFirst().map { $0.uuidString.lowercased() }.sorted())
    }

    @Test
    func reportLargerThanQueueIsNotQueued() async throws {
        StubProtocol.statuses = [503]

        let result = try await makeQueue(maxBytes: 1000).submit(makeRequest(screenshotBytes: 2000))

        #expect(result == .failed(.serviceUnavailable))
        #expect(queuedFolders.isEmpty)
    }
}

final class TestClock: @unchecked Sendable {
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    var now: Date {
        lock.withLock { start.addingTimeInterval(offset) }
    }

    func advance(by seconds: TimeInterval) {
        lock.withLock { offset += seconds }
    }
}

/// Answers each request with the next of `statuses`, or fails with `failure`.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statuses: [Int] = []
    nonisolated(unsafe) static var retryAfter: String?
    nonisolated(unsafe) static var failure: URLError?
    nonisolated(unsafe) static var received: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [Data] = []

    static func reset() {
        statuses = []
        retryAfter = nil
        failure = nil
        received = []
        bodies = []
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.received.append(request)
        Self.bodies.append(Self.body(of: request))
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let status = Self.statuses.isEmpty ? 201 : Self.statuses.removeFirst()
        var headers = ["Content-Type": "application/json"]
        headers["Retry-After"] = Self.retryAfter
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands the body to protocols as a stream.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
