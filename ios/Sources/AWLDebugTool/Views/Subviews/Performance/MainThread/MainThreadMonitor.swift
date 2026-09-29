//
//  MainThreadMonitor.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 13.06.2026.
//

import Foundation
import Combine

extension MainThreadMonitor {
    struct Snapshot {
        let timestamp: Date
        let latencyMs: CGFloat  // ms; how long main thread was busy
    }
}

final class MainThreadMonitor {
    lazy private(set) var collection = MonitorCollectionHelper<Snapshot>(
        interval: 0.1,
        historyCapacity: 600,
        queueName: "main.thread.monitor",
        readSnapshot: { [weak self] in self?.readSnapshot() }
    )

    func start() { collection.start() }

    // MARK: - Private

    private func readSnapshot() -> Snapshot? {
        // Enqueue an empty block on the main queue and measure how long we
        // wait until it executes. That wait time IS the main thread delay.
        let start = DispatchTime.now()
        DispatchQueue.main.sync { }
        let ns = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let latency = TimeInterval(ns) / 1_000_000
        return Snapshot(
            timestamp: Date(),
            latencyMs:   latency
        )
    }
}
