//
//  CPU.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 11.06.2026.
//

import Foundation
import Combine

extension CPUMonitor {
    struct CPUSnapshot {
        let timestamp: Date
        let cores: [CoreLoad]
        let threads: [ThreadLoad]
        let cpuTotalUsage: Double       // sum % of all threads
        let qos: QoSCPUTime
        let thermalState: ProcessInfo.ThermalState
        var systemCPU: Double {      // average across all cores
            guard !cores.isEmpty else { return 0 }
            return cores.map(\.active).reduce(0, +) / Double(cores.count)
        }
    }
}

// MARK: - CPUMonitor

final class CPUMonitor {
    
    // MARK: Configuration
    
    var interval: TimeInterval {
        didSet { restartTimerIfNeeded() }
    }
    
    var historyCapacity: Int {
        didSet { trimHistory() }
    }
    
    private let snapshotSubject = PassthroughSubject<CPUSnapshot, Never>()
    var snapshotPublisher: AnyPublisher<CPUSnapshot, Never> { snapshotSubject.eraseToAnyPublisher() }
    
    private(set) var history: [CPUSnapshot] = []
    
    // MARK: Private
    
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "cpu.monitor", qos: .utility)
    
    private let coresReader = CoresReader()
    
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
        let threads = Self.readThreads()
        let snapshot = CPUSnapshot(
            timestamp:     Date(),
            cores:         coresReader.readCores(),
            threads:       threads,
            cpuTotalUsage: threads.map(\.cpuUsage).reduce(0, +),
            qos:           Self.readQoS(),
            thermalState:  ProcessInfo.processInfo.thermalState
        )
        
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
    
}
