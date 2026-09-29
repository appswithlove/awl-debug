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
                              appUserId: String? = nil, samplesMetrics: Bool = false) -> RemoteReporter {
        let buffer = ReportingBuffer(root: directory, maxBytes: maxBytes) { [unowned self] in now }
        let reporter = RemoteReporter(config: config ?? self.config, buffer: buffer, appUserId: appUserId,
                                      now: { [unowned self] in now }, uptime: { [unowned self] in uptime },
                                      samplesMetrics: samplesMetrics)
        reporter.start()
        return reporter
    }

    private func drain(_ reporter: RemoteReporter) {
        reporter.queue.sync {}
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
}
