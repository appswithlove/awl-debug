import XCTest
@testable import AWLDebugTool

@MainActor
final class PerformanceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PerformanceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMonitorsRunOnlyWhileMeasuringOrOverlayVisible() {
        let tool = AWLDebugTool()
        let controller = PerformanceController(monitors: tool, defaults: defaults)
        let collections = [tool.cpuMonitor.collection.isRunning, tool.ramMonitor.collection.isRunning]

        controller.updateSampling()
        XCTAssertEqual(collections, [false, false])
        XCTAssertFalse(tool.mainThreadMonitor.collection.isRunning)
        XCTAssertFalse(tool.batteryMonitor.collection.isRunning)

        controller.isMeasuring = true
        XCTAssertTrue(tool.cpuMonitor.collection.isRunning)
        XCTAssertTrue(tool.ramMonitor.collection.isRunning)
        XCTAssertTrue(tool.mainThreadMonitor.collection.isRunning)
        XCTAssertTrue(tool.batteryMonitor.collection.isRunning)
        XCTAssertTrue(PerformanceController(monitors: AWLDebugTool(), defaults: defaults).isMeasuring)

        controller.isMeasuring = false
        XCTAssertFalse(tool.cpuMonitor.collection.isRunning)
        XCTAssertFalse(tool.mainThreadMonitor.collection.isRunning)

        defaults.set(true, forKey: DebugView.Keys.isPerformanceWidgetVisible)
        controller.updateSampling()
        XCTAssertTrue(tool.cpuMonitor.collection.isRunning)
        defaults.set(false, forKey: DebugView.Keys.isPerformanceWidgetVisible)
        controller.updateSampling()
        XCTAssertFalse(tool.cpuMonitor.collection.isRunning)
    }

    func testCPUIsNormalisedAcrossCores() {
        XCTAssertEqual(CPUMonitor.normalized(400, cores: 8), 50)
        XCTAssertEqual(CPUMonitor.normalized(900, cores: 8), 100)
        XCTAssertEqual(CPUMonitor.normalized(50, cores: 0), 50)
    }

    /// Compares the monitor's reading with the CPU time the process really used in the same window, so a busy
    /// machine (where the load threads get little CPU) does not fail the test.
    func testCPUReadingMatchesTheProcessCPUTimeUnderLoad() {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let idle = CPUMonitor.normalized(CPUMonitor.readThreads().map(\.cpuUsage).reduce(0, +), cores: cores)

        let end = Date().addingTimeInterval(2)
        for _ in 0..<cores {
            Thread.detachNewThread {
                while Date() < end {}
            }
        }
        // thread_basic_info.cpu_usage is a decaying average over roughly the last second.
        Thread.sleep(forTimeInterval: 0.5)
        let wallStart = Date()
        let cpuStart = Self.processCPUTime()
        Thread.sleep(forTimeInterval: 1)
        let reading = CPUMonitor.normalized(CPUMonitor.readThreads().map(\.cpuUsage).reduce(0, +), cores: cores)
        let consumed = (Self.processCPUTime() - cpuStart) / Date().timeIntervalSince(wallStart) / Double(cores) * 100
        Thread.sleep(until: end)

        XCTAssertGreaterThan(consumed, 0)
        XCTAssertEqual(Double(reading), consumed, accuracy: max(15, consumed * 0.5),
                       "monitor \(reading) % vs. consumed \(consumed) % (idle \(idle) %)")
        XCTAssertGreaterThan(reading, idle)
    }

    /// User plus system CPU time of the whole process, in seconds.
    private static func processCPUTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }

    func testBlockedMainThreadCountsAsFreeze() {
        let monitor = MainThreadMonitor()
        monitor.start()
        defer { monitor.stop() }

        Thread.sleep(forTimeInterval: 1.5)

        let deadline = Date().addingTimeInterval(3)
        while monitor.freezeCount == 0 && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(monitor.freezeCount, 1)
        XCTAssertGreaterThanOrEqual(monitor.longestFreezeMs, 1400)
    }
}
