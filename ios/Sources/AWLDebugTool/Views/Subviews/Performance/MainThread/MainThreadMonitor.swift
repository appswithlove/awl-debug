//
//  MainThreadMonitor.swift
//  AWLDebugTool
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
    /// A ping that waits longer than this counts as a UI freeze.
    static let freezeThresholdMs: CGFloat = 700

    lazy private(set) var collection = MonitorCollectionHelper<Snapshot>(
        interval: 0.1,
        historyCapacity: 600,
        queueName: "main.thread.monitor",
        readSnapshot: { [weak self] in self?.readSnapshot() }
    )

    /// Freezes since the measurement started; updated on the main thread.
    private(set) var freezeCount = 0
    private(set) var longestFreezeMs: CGFloat = 0
    private var freezeCounting: AnyCancellable?

    func start() {
        guard !collection.isRunning else { return }
        freezeCount = 0
        longestFreezeMs = 0
        freezeCounting = collection.snapshotPublisher.sink { [weak self] snapshot in
            self?.record(snapshot)
        }
        collection.start()
    }

    func stop() {
        collection.stop()
        freezeCounting = nil
    }

    func record(_ snapshot: Snapshot) {
        guard snapshot.latencyMs > Self.freezeThresholdMs else { return }
        freezeCount += 1
        longestFreezeMs = max(longestFreezeMs, snapshot.latencyMs)
    }

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
