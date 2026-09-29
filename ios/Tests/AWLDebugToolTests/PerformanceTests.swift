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

    func testFullLoadOnAllCoresIsAboveHalf() {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let end = Date().addingTimeInterval(1.5)
        for _ in 0..<cores {
            Thread.detachNewThread {
                while Date() < end {}
            }
        }
        Thread.sleep(forTimeInterval: 1)

        let total = CPUMonitor.readThreads().map(\.cpuUsage).reduce(0, +)
        XCTAssertGreaterThan(CPUMonitor.normalized(total, cores: cores), 50)
        Thread.sleep(until: end)
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
