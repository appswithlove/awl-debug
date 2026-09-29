import Foundation

/// Runs the performance monitors only while they are needed: the "Measure performance" switch is on or the
/// overlay is visible. Otherwise no timer runs.
@MainActor
final class PerformanceController: ObservableObject {
    @Published var isMeasuring: Bool {
        didSet {
            defaults.set(isMeasuring, forKey: Constants.UserDefaultsKey.performanceMeasuring)
            updateSampling()
        }
    }

    private let monitors: AWLDebugTool
    private let defaults: UserDefaults

    init(monitors: AWLDebugTool, defaults: UserDefaults = .standard) {
        self.monitors = monitors
        self.defaults = defaults
        isMeasuring = defaults.bool(forKey: Constants.UserDefaultsKey.performanceMeasuring)
    }

    var isOverlayVisible: Bool {
        defaults.bool(forKey: DebugView.Keys.isPerformanceWidgetVisible)
    }

    var isSampling: Bool {
        monitors.cpuMonitor.collection.isRunning
    }

    func updateSampling() {
        let shouldRun = isMeasuring || isOverlayVisible
        guard shouldRun != isSampling else { return }
        if shouldRun {
            monitors.cpuMonitor.start()
            monitors.ramMonitor.start()
            monitors.mainThreadMonitor.start()
            monitors.batteryMonitor.start()
        } else {
            monitors.cpuMonitor.stop()
            monitors.ramMonitor.stop()
            monitors.mainThreadMonitor.stop()
            monitors.batteryMonitor.stop()
        }
    }
}
