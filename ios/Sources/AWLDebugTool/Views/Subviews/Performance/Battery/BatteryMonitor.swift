import UIKit

extension BatteryMonitor {
    struct Snapshot {
        let timestamp: Date
        /// 0–100, `nil` where the level is unknown (simulator).
        let percent: Double?
        let state: UIDevice.BatteryState
    }
}

/// Battery level; monitoring is enabled only while measuring.
final class BatteryMonitor {
    lazy private(set) var collection = MonitorCollectionHelper<Snapshot>(interval: 1, historyCapacity: 120, queueName: "battery.monitor", readSnapshot: {
        Self.readSnapshot()
    })

    func start() {
        DispatchQueue.main.async {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        collection.start()
    }

    func stop() {
        collection.stop()
        DispatchQueue.main.async {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
    }

    private static func readSnapshot() -> Snapshot {
        let (level, state) = DispatchQueue.main.sync { (UIDevice.current.batteryLevel, UIDevice.current.batteryState) }
        return Snapshot(timestamp: Date(), percent: level < 0 ? nil : Double(level) * 100, state: state)
    }
}
