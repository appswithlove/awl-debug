import XCTest
@testable import AWLDebugTool

/// Compares a captured session with a plain one against a local server. Prints `PERF` lines; the bounds are loose,
/// so the tests only fail when capturing slows the app down by an order of magnitude.
/// Skipped unless `AWL_BENCHMARKS=1`, because their load makes timing tests on shared CI runners flaky:
/// `TEST_RUNNER_AWL_BENCHMARKS=1 xcodebuild test -scheme AWLDebugTool -only-testing:AWLDebugToolTests/NetworkCapturePerformanceTests …`
final class NetworkCapturePerformanceTests: XCTestCase {

    private var server: LocalHTTPServer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(ProcessInfo.processInfo.environment["AWL_BENCHMARKS"] == "1", "Benchmarks run with TEST_RUNNER_AWL_BENCHMARKS=1")
        server = try LocalHTTPServer()
    }

    override func tearDown() {
        server?.stop()
        super.tearDown()
    }

    private func session(captured: Bool, delegate: URLSessionDelegate? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        if captured {
            configuration.protocolClasses = [AWLDebugURLProtocol.self] + (configuration.protocolClasses ?? [])
        }
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private func report(_ name: String, plain: Double, captured: Double, unit: String) {
        print(String(format: "PERF %@ plain=%.1f%@ captured=%.1f%@", name, plain, unit, captured, unit))
    }

    // MARK: - Many small requests

    func testManySmallRequests() {
        server.route("/small", .init(headers: [("Content-Type", "application/json")], body: Data(#"{"id":1,"token":"t"}"#.utf8)))
        let count = 300

        func sequential(captured: Bool) -> Double {
            let session = session(captured: captured)
            defer { session.invalidateAndCancel() }
            let start = Date()
            for _ in 0..<count {
                let done = expectation(description: "small")
                session.dataTask(with: server.url("/small")) { _, _, _ in done.fulfill() }.resume()
                wait(for: [done], timeout: 10)
            }
            return Date().timeIntervalSince(start) * 1000 / Double(count)
        }

        func concurrent(captured: Bool) -> (total: Double, mainLatency: Double) {
            let session = session(captured: captured)
            defer { session.invalidateAndCancel() }
            let probe = MainThreadLatencyProbe()
            let done = expectation(description: "burst")
            done.expectedFulfillmentCount = count
            let start = Date()
            for _ in 0..<count {
                session.dataTask(with: server.url("/small")) { _, _, _ in done.fulfill() }.resume()
            }
            wait(for: [done], timeout: 30)
            let total = Date().timeIntervalSince(start) * 1000
            return (total, probe.stop())
        }

        _ = sequential(captured: false) // warm-up
        let plain = sequential(captured: false)
        let captured = sequential(captured: true)
        report("small-sequential-per-request", plain: plain, captured: captured, unit: "ms")
        XCTAssertLessThan(captured, plain * 10 + 5)

        let plainBurst = concurrent(captured: false)
        let capturedBurst = concurrent(captured: true)
        report("small-burst-\(count)-total", plain: plainBurst.total, captured: capturedBurst.total, unit: "ms")
        report("small-burst-max-main-thread-latency", plain: plainBurst.mainLatency, captured: capturedBurst.mainLatency, unit: "ms")
    }

    // MARK: - Large response

    func testLargeResponse() {
        let size = 30 * 1024 * 1024
        server.route("/large", .init(headers: [("Content-Type", "application/json")], body: Data(repeating: 0x61, count: size)))

        func load(captured: Bool) -> (ms: Double, peakExtraMB: Double) {
            let session = session(captured: captured)
            defer { session.invalidateAndCancel() }
            let memory = PeakMemoryProbe()
            let done = expectation(description: "large")
            var received = 0
            let start = Date()
            session.dataTask(with: server.url("/large")) { data, _, _ in
                received = data?.count ?? 0
                done.fulfill()
            }.resume()
            wait(for: [done], timeout: 60)
            let ms = Date().timeIntervalSince(start) * 1000
            XCTAssertEqual(received, size)
            return (ms, memory.stop())
        }

        _ = load(captured: false) // warm-up
        let plain = load(captured: false)
        let captured = load(captured: true)
        report("large-30MB-duration", plain: plain.ms, captured: captured.ms, unit: "ms")
        report("large-30MB-peak-extra-memory", plain: plain.peakExtraMB, captured: captured.peakExtraMB, unit: "MB")
        XCTAssertLessThan(captured.ms, plain.ms * 10 + 1000)
    }

    // MARK: - Streaming

    func testStreamingTimeToFirstChunk() {
        let chunks = (0..<5).map { Data("data: event \($0)\n\n".utf8) }
        server.route("/sse", .init(headers: [("Content-Type", "text/event-stream")], chunks: chunks, chunkInterval: 0.3))
        server.route("/ndjson", .init(headers: [("Content-Type", "application/json")], chunks: chunks, chunkInterval: 0.3))

        func firstChunk(_ path: String, accept: String?, captured: Bool) -> Double {
            let receiver = FirstChunkReceiver()
            let session = session(captured: captured, delegate: receiver)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: server.url(path))
            request.setValue(accept, forHTTPHeaderField: "Accept")
            receiver.expectation = expectation(description: path)
            let start = Date()
            session.dataTask(with: request).resume()
            wait(for: [receiver.expectation!], timeout: 10)
            return (receiver.firstChunkAt ?? .distantFuture).timeIntervalSince(start) * 1000
        }

        for (path, accept) in [("/sse", "text/event-stream"), ("/ndjson", nil)] {
            let plain = firstChunk(path, accept: accept, captured: false)
            let captured = firstChunk(path, accept: accept, captured: true)
            report("stream\(path)-time-to-first-chunk", plain: plain, captured: captured, unit: "ms")
            XCTAssertLessThan(captured, 1_000, "the first event must reach the app before the stream ends")
        }
    }
}

private final class FirstChunkReceiver: NSObject, URLSessionDataDelegate {
    var expectation: XCTestExpectation?
    private(set) var firstChunkAt: Date?

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard firstChunkAt == nil else { return }
        firstChunkAt = Date()
        expectation?.fulfill()
    }
}

/// Largest delay of a block dispatched to the main queue every 5 ms.
private final class MainThreadLatencyProbe {
    private let timer: DispatchSourceTimer
    private let lock = NSLock()
    private var maxLatency: Double = 0

    init() {
        timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now(), repeating: .milliseconds(5))
        timer.setEventHandler { [self] in
            let sent = Date()
            DispatchQueue.main.async { [self] in
                let latency = Date().timeIntervalSince(sent) * 1000
                lock.lock()
                maxLatency = max(maxLatency, latency)
                lock.unlock()
            }
        }
        timer.resume()
    }

    func stop() -> Double {
        timer.cancel()
        lock.lock()
        defer { lock.unlock() }
        return maxLatency
    }
}

/// Highest `phys_footprint` above the value at creation, sampled every 5 ms.
private final class PeakMemoryProbe {
    private let timer: DispatchSourceTimer
    private let baseline = PeakMemoryProbe.footprint()
    private let lock = NSLock()
    private var peak: UInt64 = 0

    init() {
        peak = baseline
        timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now(), repeating: .milliseconds(5))
        timer.setEventHandler { [self] in
            let value = Self.footprint()
            lock.lock()
            peak = max(peak, value)
            lock.unlock()
        }
        timer.resume()
    }

    func stop() -> Double {
        timer.cancel()
        lock.lock()
        defer { lock.unlock() }
        return Double(peak - baseline) / 1_048_576
    }

    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
