//
//  MonitorHelper.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 13.06.2026.
//

import Foundation
import Combine

class MonitorCollectionHelper<T> {
    
    var interval: TimeInterval {
        didSet { restartTimerIfNeeded() }
    }

    var historyCapacity: Int {
        didSet { trimHistory() }
    }

    private let snapshotSubject = PassthroughSubject<T, Never>()
    var snapshotPublisher: AnyPublisher<T, Never> { snapshotSubject.eraseToAnyPublisher() }

    // MARK: Public read-only

    /// Ring buffer of the last N snapshots
    private(set) var history: [T] = []

    // MARK: Private

    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue
    
    private let readSnapshot: () -> T?
    
    init(interval: TimeInterval, historyCapacity: Int, queueName: String, readSnapshot: @escaping () -> T?) {
        self.interval = interval
        self.historyCapacity = historyCapacity
        self.queue = DispatchQueue(label: queueName, qos: .utility)
        self.readSnapshot = readSnapshot
    }
    
    deinit {
        stop()
    }

    // MARK: Control

    func start() {
        guard timer == nil else { return }
        scheduleTimer()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    var isRunning: Bool { timer != nil }

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
    
    private func collect() {
        let snapshot = readSnapshot()

        DispatchQueue.main.async { [weak self] in
            guard let self, let snapshot else { return }
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
}
