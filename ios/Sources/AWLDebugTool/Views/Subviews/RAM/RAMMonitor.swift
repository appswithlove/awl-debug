//
//  RAMMonitor.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 12.06.2026.
//

import Foundation
import Combine

extension RAMMonitor {
    struct RAMSnapshot {
        let timestamp: Date

        // App (bytes)
        let footprint: UInt64        // phys_footprint — what Xcode and jetsam track
        let peakFootprint: UInt64    // lifetime maximum of phys_footprint
        let resident: UInt64         // resident set size
        let available: UInt64        // memory left before hitting the jetsam limit

        // System (bytes)
        let totalPhysical: UInt64
        let free: UInt64
        let active: UInt64
        let inactive: UInt64
        let wired: UInt64
        let compressed: UInt64
    }
}

// MARK: - RAMMonitor

final class RAMMonitor {

    // MARK: Configuration

    var interval: TimeInterval {
        didSet { restartTimerIfNeeded() }
    }

    var historyCapacity: Int {
        didSet { trimHistory() }
    }

    private let snapshotSubject = PassthroughSubject<RAMSnapshot, Never>()
    var snapshotPublisher: AnyPublisher<RAMSnapshot, Never> { snapshotSubject.eraseToAnyPublisher() }

    // MARK: Public read-only

    /// Ring buffer of the last N snapshots
    private(set) var history: [RAMSnapshot] = []

    // MARK: Private

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "ram.monitor", qos: .utility)

    // MARK: Init

    public init(interval: TimeInterval = 0.5, historyCapacity: Int = 120) {
        self.interval = interval
        self.historyCapacity = historyCapacity
    }

    deinit {
        stop()
    }

    // MARK: Control

    public func start() {
        guard timer == nil else { return }
        scheduleTimer()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public var isRunning: Bool { timer != nil }

    // MARK: - Timer

    private func scheduleTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(20))
        t.setEventHandler { [weak self] in self?.collect() }
        t.resume()
        timer = t
    }

    private func restartTimerIfNeeded() {
        guard isRunning else { return }
        stop()
        start()
    }

    // MARK: - Collection

    private func collect() {
        let snapshot = readSnapshot()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.history.append(snapshot)
            self.trimHistory()
            self.snapshotSubject.send(snapshot)
        }
    }

    private func trimHistory() {
        if history.count > historyCapacity {
            history.removeFirst(history.count - historyCapacity)
        }
    }

    private func readSnapshot() -> RAMSnapshot {
        let app = Self.readAppMemory()
        let system = Self.readSystemMemory()

        return RAMSnapshot(
            timestamp:     Date(),
            footprint:     app.footprint,
            peakFootprint: Self.readPeakFootprint(),
            resident:      app.resident,
            available:     UInt64(max(os_proc_available_memory(), 0)),
            totalPhysical: ProcessInfo.processInfo.physicalMemory,
            free:          system.free,
            active:        system.active,
            inactive:      system.inactive,
            wired:         system.wired,
            compressed:    system.compressed
        )
    }
}
