import XCTest
import zlib
@testable import AWLDebugTool

/// Builds real batches from requests captured by `AWLDebugURLProtocol`. Every batch is also written to
/// `.build/contract/` at the repository root for a local schema check:
/// `uvx --from check-jsonschema check-jsonschema --schemafile <session-batch.v1.schema.json> .build/contract/*.json`
final class RemoteReportingTests: XCTestCase {

    private var directory: URL!
    private var now: Int64 = 1_790_000_000_000
    private var uptime: TimeInterval = 1_000

    private let config = RemoteReportingConfig(endpoint: URL(string: "https://feedback.example.ch/")!,
                                               appKey: "fbk_test",
                                               environment: "staging",
                                               distribution: .internal)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("reporting-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeReporter(config: RemoteReportingConfig? = nil, maxBytes: Int = ReportingBuffer.defaultMaxBytes,
                              appUserId: String? = nil, samplesMetrics: Bool = false, uploads: Bool = false) -> RemoteReporter {
        let buffer = ReportingBuffer(root: directory, maxBytes: maxBytes) { [unowned self] in now }
        let reporter = RemoteReporter(config: config ?? self.config, buffer: buffer, appUserId: appUserId,
                                      now: { [unowned self] in now }, uptime: { [unowned self] in uptime },
                                      samplesMetrics: samplesMetrics, uploads: uploads)
        reporter.start()
        return reporter
    }

    private func drain(_ reporter: RemoteReporter) {
        reporter.queue.sync {}
    }

    private func flushAndWait(_ reporter: RemoteReporter, ignoringBackoff: Bool = true) {
        let done = expectation(description: "flushed")
        reporter.flush(ignoringBackoff: ignoringBackoff) { done.fulfill() }
        wait(for: [done], timeout: 15)
    }

    private func uploadState(_ reporter: RemoteReporter) -> ReportingUploader.State {
        reporter.queue.sync { reporter.uploader?.state ?? .init() }
    }

    private func uploadingReporter(to server: LocalHTTPServer) -> RemoteReporter {
        var config = config
        config.endpoint = server.url("/")
        let reporter = makeReporter(config: config, uploads: true)
        reporter.onForeground()
        return reporter
    }

    /// Sealed batches as JSON objects, oldest first; each is also written for the schema check.
    private func batches(_ reporter: RemoteReporter, name: String = #function) throws -> [[String: Any]] {
        drain(reporter)
        let contract = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/contract", isDirectory: true)
        try FileManager.default.createDirectory(at: contract, withIntermediateDirectories: true)
        return try reporter.buffer.sealedBatches().enumerated().map { index, file in
            let json = try XCTUnwrap(gunzip(try Data(contentsOf: file)))
            let testName = name.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            try json.write(to: contract.appendingPathComponent("ios-\(testName)-\(index).json"))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        }
    }

    private func gunzip(_ data: Data) -> Data? {
        var stream = z_stream()
        guard inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        var output = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        var status = Z_OK
        data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)
            repeat {
                chunk.withUnsafeMutableBufferPointer { buffer in
                    stream.next_out = buffer.baseAddress
                    stream.avail_out = uInt(buffer.count)
                    status = inflate(&stream, Z_NO_FLUSH)
                    output.append(buffer.baseAddress!, count: buffer.count - Int(stream.avail_out))
                }
            } while status == Z_OK
        }
        return status == Z_STREAM_END ? output : nil
    }

    private func capture(_ request: URLRequest) throws -> NetworkLog {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let loaded = expectation(description: "loaded")
        session.dataTask(with: request) { _, _, _ in loaded.fulfill() }.resume()
        wait(for: [loaded], timeout: 10)

        let url = try XCTUnwrap(request.url?.absoluteString)
        let logged = expectation(description: "logged")
        var log: NetworkLog?
        func poll() {
            log = AWLDebugTool.shared.networkLogger.networkTraffic.last { $0.url.hasPrefix(url.components(separatedBy: "?")[0]) }
            if log == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            } else {
                logged.fulfill()
            }
        }
        DispatchQueue.main.async(execute: poll)
        wait(for: [logged], timeout: 5)
        return try XCTUnwrap(log)
    }

    private func metric(at millis: Int64, cpu: Double = 12.34) -> ReportingMetricSample {
        ReportingMetricSample(timestampMillis: millis, cpuPercent: cpu, ramBytes: 123_456_789, batteryPercent: 80, uiFreezeMs: 16)
    }

    // MARK: - Tests

    func testBatchFromCapturedRequestsIsRedactedAndHashed() throws {
        let server = try LocalHTTPServer()
        defer { server.stop() }
        server.route("/items", .init(headers: [("Content-Type", "application/json"), ("Set-Cookie", "session=abc")],
                                     body: Data(#"{"items":[1,2]}"#.utf8)))
        var request = URLRequest(url: server.url("/items?token=secret&page=1"))
        request.httpMethod = "POST"
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("key-secret", forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"name":"a"}"#.utf8)
        let ok = try capture(request)
        let failed = try capture(URLRequest(url: URL(string: "http://127.0.0.1:1/down")!))

        let reporter = makeReporter(appUserId: "42")
        reporter.onForeground()
        reporter.record(ok)
        reporter.record(failed)
        reporter.record(metric(at: now))
        now += 5_000
        reporter.onBackground()

        let batch = try XCTUnwrap(try batches(reporter).first)
        let session = try XCTUnwrap(batch["session"] as? [String: Any])
        XCTAssertEqual(session["platform"] as? String, "ios")
        XCTAssertEqual(session["distribution"] as? String, "internal")
        XCTAssertEqual(session["endedAt"] as? String, ReportingJSON.timestamp(now))
        XCTAssertEqual(session["userIdentifier"] as? String, ReportingJSON.userIdentifier(appKey: "fbk_test", appUserId: "42"))
        XCTAssertEqual((session["userIdentifier"] as? String)?.count, 64)

        let logs = try XCTUnwrap(batch["networkLogs"] as? [[String: Any]])
        XCTAssertEqual(logs.count, 2)
        let headers = try XCTUnwrap(logs[0]["requestHeaders"] as? [String: String])
        XCTAssertEqual(headers["authorization"], "[REDACTED]")
        XCTAssertEqual(headers["x-api-key"], "[REDACTED]")
        XCTAssertEqual((logs[0]["responseHeaders"] as? [String: String])?["set-cookie"], "[REDACTED]")
        XCTAssertEqual(logs[0]["status"] as? Int, 200)
        XCTAssertTrue((logs[0]["url"] as? String)?.hasSuffix("/items?token=[REDACTED]&page=1") == true)
        XCTAssertNil(logs[0]["requestBody"], "bodies are off by default")
        XCTAssertNil(logs[0]["responseBody"])
        XCTAssertNil(logs[1]["status"], "no status without a response")
        XCTAssertNotNil(logs[1]["error"])

        let metrics = try XCTUnwrap(batch["metrics"] as? [[String: Any]])
        XCTAssertEqual(metrics.first?["cpuPercent"] as? Double, 12.3)
        let raw = String(decoding: try JSONSerialization.data(withJSONObject: batch), as: UTF8.self)
        XCTAssertFalse(raw.contains("secret"))
    }

    func testBodiesAreCappedWhenEnabled() throws {
        var config = config
        config.captureBodies = true
        config.maxBodyBytes = 16
        var log = NetworkLog(id: UUID(), method: "GET", url: "https://api.example.ch/a", date: Date(), duration: 5, statusCode: 200)
        log.responseBody = .init(text: String(repeating: "x", count: 100), contentType: "text/plain", originalBytes: 100)
        log.requestBody = .init(text: "(binary, 3 bytes)", contentType: "image/png", originalBytes: 3, isText: false)
        let reporter = makeReporter(config: config)
        reporter.record(log)
        reporter.flush()

        let entry = try XCTUnwrap((try batches(reporter).first?["networkLogs"] as? [[String: Any]])?.first)
        let body = try XCTUnwrap(entry["responseBody"] as? [String: Any])
        XCTAssertEqual(body["text"] as? String, String(repeating: "x", count: 16))
        XCTAssertEqual(body["truncated"] as? Bool, true)
        XCTAssertEqual(body["originalBytes"] as? Int, 100)
        XCTAssertNil(entry["requestBody"], "placeholders are not sent")
    }

    func testOwnRequestsToTheServiceAreNotRecorded() throws {
        let reporter = makeReporter()
        reporter.record(NetworkLog(id: UUID(), method: "POST", url: "https://feedback.example.ch/v1/sessions/batch",
                                   date: Date(), duration: 5, statusCode: 200))
        reporter.flush()
        XCTAssertTrue(try batches(reporter).isEmpty)
    }

    func testSessionContinuesWithin30MinutesAndRenewsAfter() throws {
        let reporter = makeReporter()
        reporter.onForeground()
        reporter.record(metric(at: now))
        reporter.onBackground()
        drain(reporter)
        let first = try XCTUnwrap(reporter.session)
        XCTAssertNotNil(first.endedAtMillis)

        uptime += 10 * 60
        reporter.onForeground()
        drain(reporter)
        XCTAssertEqual(reporter.session?.id, first.id)
        XCTAssertNil(reporter.session?.endedAtMillis)

        reporter.onBackground()
        drain(reporter)
        uptime += 31 * 60
        now += 31 * 60 * 1000
        reporter.onForeground()
        drain(reporter)
        XCTAssertNotEqual(reporter.session?.id, first.id)

        let sessions = try batches(reporter).compactMap { ($0["session"] as? [String: Any])?["id"] as? String }
        XCTAssertEqual(Set(sessions), [first.id])
    }

    func testLeftoverSessionIsSentWithEndedAtOfItsLastEntry() throws {
        let crashed = makeReporter()
        crashed.onForeground()
        crashed.record(metric(at: now))
        crashed.record(metric(at: now + 5_000))
        drain(crashed)
        let lastEntry = now + 5_000

        now += 60_000
        let restarted = makeReporter()
        let batch = try XCTUnwrap(try batches(restarted).first)
        let session = try XCTUnwrap(batch["session"] as? [String: Any])
        XCTAssertEqual(session["id"] as? String, crashed.session?.id)
        XCTAssertEqual(session["endedAt"] as? String, ReportingJSON.timestamp(lastEntry))
        XCTAssertEqual((batch["metrics"] as? [Any])?.count, 2)
    }

    func testFullBufferDropsOldestEntriesAndReportsDroppedCount() throws {
        let maxBytes = 20_000
        let reporter = makeReporter(maxBytes: maxBytes)
        reporter.onForeground()
        for index in 0..<500 {
            reporter.record(metric(at: now + Int64(index) * 5_000))
        }
        drain(reporter)
        XCTAssertLessThanOrEqual(reporter.buffer.sizeBytes, maxBytes)
        reporter.onBackground()

        let batch = try XCTUnwrap(try batches(reporter).first)
        let dropped = try XCTUnwrap(batch["droppedCount"] as? Int)
        let sent = try XCTUnwrap(batch["metrics"] as? [[String: Any]])
        XCTAssertEqual(dropped + sent.count, 500)
        XCTAssertEqual(sent.last?["ts"] as? String, ReportingJSON.timestamp(now + 499 * 5_000), "newest entries are kept")
    }

    func testBatchesHoldAtMost2000EntriesEach() throws {
        let reporter = makeReporter()
        reporter.onForeground()
        for index in 0..<2_500 {
            reporter.record(metric(at: now + Int64(index)))
        }
        reporter.flush()

        let all = try batches(reporter)
        XCTAssertEqual(all.map { ($0["metrics"] as? [Any])?.count }, [2_000, 500])
        XCTAssertEqual(Set(all.compactMap { $0["batchId"] as? String }).count, 2)
        XCTAssertNil(all[0]["droppedCount"])
    }

    func testStoreBuildRecordsNothing() {
        var config = config
        config.distribution = .store
        let reporting = RemoteReporting()
        reporting.start(config: config, directory: directory)
        reporting.flush()

        XCTAssertEqual(reporting.status, .storeBuild)
        XCTAssertNil(reporting.reporter)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    // MARK: - Transport

    func testUploadRetriesTheSameBatchUntilAccepted() throws {
        let server = try LocalHTTPServer()
        defer { server.stop() }
        let path = "/v1/sessions/batch"
        server.route(path, .init(status: "503 Service Unavailable"))
        let reporter = uploadingReporter(to: server)
        reporter.record(metric(at: now))
        flushAndWait(reporter)

        XCTAssertEqual(server.hitCount(path), 1)
        let headers = server.receivedHeaders(path)
        XCTAssertEqual(headers["x-app-key"], "fbk_test")
        XCTAssertEqual(headers["content-encoding"], "gzip")
        XCTAssertEqual(headers["content-type"], "application/json")
        let first = try XCTUnwrap(server.receivedBody(path))
        let batch = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(gunzip(first))) as? [String: Any])
        XCTAssertEqual((batch["metrics"] as? [Any])?.count, 1)
        XCTAssertEqual(uploadState(reporter).pendingCount, 1)

        // Within the backoff only an explicit flush sends; a 429 with Retry-After blocks that, too.
        server.route(path, .init(status: "429 Too Many Requests", headers: [("Retry-After", "120")]))
        flushAndWait(reporter, ignoringBackoff: false)
        XCTAssertEqual(server.hitCount(path), 1)
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount(path), 2)
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount(path), 2, "Retry-After is respected")

        uptime += 121
        server.route(path, .init(body: Data(#"{"status":"accepted"}"#.utf8)))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount(path), 3)
        XCTAssertEqual(server.receivedBody(path), first, "a retry sends the same bytes and batchId")
        XCTAssertTrue(reporter.queue.sync { reporter.buffer.sealedBatches().isEmpty })
        let state = uploadState(reporter)
        XCTAssertEqual(state.pendingCount, 0)
        XCTAssertNotNil(state.lastSentAt)
        XCTAssertNil(state.problem)
    }

    func testRejectedBatchIsDroppedAndForbiddenStopsReporting() throws {
        let server = try LocalHTTPServer()
        defer { server.stop() }
        let path = "/v1/sessions/batch"
        server.route(path, .init(status: "422 Unprocessable Entity", body: Data(#"{"error":"distribution_not_allowed"}"#.utf8)))
        let reporter = uploadingReporter(to: server)
        reporter.record(metric(at: now))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount(path), 1)
        XCTAssertEqual(uploadState(reporter).problem, .rejected(status: 422))
        XCTAssertEqual(uploadState(reporter).pendingCount, 0, "a rejected batch is dropped, not retried")

        server.route(path, .init(status: "403 Forbidden", body: Data(#"{"error":"reporting_disabled"}"#.utf8)))
        reporter.record(metric(at: now + 5_000))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount(path), 2)
        XCTAssertEqual(uploadState(reporter).problem, .disabledByServer)
        XCTAssertTrue(uploadState(reporter).isStopped)

        server.route(path, .init())
        reporter.record(metric(at: now + 10_000))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount(path), 2, "nothing is sent until the next app start")
        XCTAssertEqual(uploadState(reporter).pendingCount, 1, "nothing new is recorded")
    }

    func testOwnRequestsAreNeverCaptured() throws {
        URLSessionConfiguration.setupSwizzle()
        let classes = ReportingUploader.sessionConfiguration().protocolClasses ?? []
        XCTAssertFalse(classes.contains { ObjectIdentifier($0) == ObjectIdentifier(AWLDebugURLProtocol.self) })
        let request = NSMutableURLRequest(url: URL(string: "https://feedback.example.ch/v1/sessions/batch")!)
        URLProtocol.setProperty(true, forKey: AWLDebugURLProtocol.Constants.SkipCaptureKey, in: request)
        XCTAssertFalse(AWLDebugURLProtocol.canInit(with: request as URLRequest))

        let server = try LocalHTTPServer()
        defer { server.stop() }
        let reporter = uploadingReporter(to: server)
        reporter.record(metric(at: now))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount("/v1/sessions/batch"), 1)
        let captured = expectation(description: "main")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { captured.fulfill() }
        wait(for: [captured], timeout: 2)
        XCTAssertFalse(AWLDebugTool.shared.networkLogger.networkTraffic.contains { $0.url.contains("/v1/sessions/batch") })
    }

    func testSendingSwitchOffRecordsAndSendsNothing() throws {
        let server = try LocalHTTPServer()
        defer { server.stop() }
        let reporter = uploadingReporter(to: server)
        reporter.setEnabled(false)
        reporter.record(metric(at: now))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount("/v1/sessions/batch"), 0)

        reporter.setEnabled(true)
        reporter.record(metric(at: now + 5_000))
        flushAndWait(reporter)
        XCTAssertEqual(server.hitCount("/v1/sessions/batch"), 1)
        let body = try XCTUnwrap(server.receivedBody("/v1/sessions/batch").flatMap(gunzip))
        let batch = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual((batch["metrics"] as? [Any])?.count, 1)
    }

    func testRetryAfterParsing() {
        XCTAssertEqual(ReportingUploader.retryAfterSeconds("120"), 120)
        let date = Date().addingTimeInterval(60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let seconds = ReportingUploader.retryAfterSeconds(formatter.string(from: date))
        XCTAssertEqual(seconds ?? 0, 60, accuracy: 2)
        XCTAssertNil(ReportingUploader.retryAfterSeconds("soon"))
    }

    func testSamplerMeasuresCPUAndMemory() throws {
        let reporter = makeReporter(samplesMetrics: true)
        reporter.onForeground()
        let sampled = expectation(description: "sampled")
        DispatchQueue.main.asyncAfter(deadline: .now() + ReportingMetricsSampler.interval + 1.5) { sampled.fulfill() }
        wait(for: [sampled], timeout: ReportingMetricsSampler.interval + 5)
        reporter.onBackground()

        let sample = try XCTUnwrap((try batches(reporter).first?["metrics"] as? [[String: Any]])?.first)
        let cpu = try XCTUnwrap(sample["cpuPercent"] as? Double)
        XCTAssertTrue((0...100).contains(cpu))
        XCTAssertGreaterThan(try XCTUnwrap(sample["ramBytes"] as? Int), 0)
    }

    func testUIFreezeIsTheLongestGapBetweenFrames() throws {
        let tracker = FrameGapTracker()
        tracker.start()
        defer { tracker.stop() }
        let framesRun = expectation(description: "frames run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { framesRun.fulfill() }
        wait(for: [framesRun], timeout: 2)
        _ = tracker.takeLongestStallMs()

        // Tests run on the main thread: this blocks it like a frozen UI.
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(tracker.takeLongestStallMs()), 1_400, "counted before the next frame")

        let framesResume = expectation(description: "frames resume")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { framesResume.fulfill() }
        wait(for: [framesResume], timeout: 2)
        XCTAssertLessThan(try XCTUnwrap(tracker.takeLongestStallMs()), 1_000, "the same stall is not counted twice")
    }

    func testLimitsHoldForMultiByteTextAndUppercaseScheme() throws {
        var log = NetworkLog(id: UUID(), method: "GET", url: "HTTPS://api.example.ch/a", date: Date(), duration: 5, statusCode: 0)
        log.requestHeaders = [.init(name: "X-Note", value: String(repeating: "😀", count: 3_000))]
        log.errorDescription = String(repeating: "é", count: 1_200)
        let reporter = makeReporter()
        reporter.record(log)
        reporter.flush()

        let entry = try XCTUnwrap((try batches(reporter).first?["networkLogs"] as? [[String: Any]])?.first)
        XCTAssertEqual(entry["url"] as? String, "https://api.example.ch/a")
        XCTAssertEqual((entry["requestHeaders"] as? [String: String])?["x-note"]?.utf16.count, 4_096)
        XCTAssertEqual((entry["error"] as? String)?.count, 1_000)
    }
}
