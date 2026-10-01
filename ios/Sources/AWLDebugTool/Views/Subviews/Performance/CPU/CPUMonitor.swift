//
//  CPU.swift
//  AWLDebugTool
//

import Foundation
import Combine

extension CPUMonitor {
    struct CPUSnapshot {
        let timestamp: Date
        let cores: [CoreLoad]
        let threads: [ThreadLoad]
        let cpuTotalUsage: CGFloat       // sum % of all threads, up to 100 per core
        let thermalState: ProcessInfo.ThermalState
        /// Process CPU on a 0–100 scale across all cores.
        var cpuPercent: CGFloat {
            CPUMonitor.normalized(cpuTotalUsage, cores: ProcessInfo.processInfo.activeProcessorCount)
        }
        var systemCPU: Double {      // average across all cores
            guard !cores.isEmpty else { return 0 }
            return cores.map(\.active).reduce(0, +) / Double(cores.count)
        }
    }
}

// MARK: - CPUMonitor

final class CPUMonitor {
    lazy private(set) var collection = MonitorCollectionHelper<CPUSnapshot>(interval: 1, historyCapacity: 120, queueName: "cpu.monitor", readSnapshot: { [weak self] in
        self?.readSnapshot()
    })
    
    private let coresReader = CoresReader()
    
    init() {
        //
    }
    
    func start() {
        collection.start()
    }

    func stop() {
        collection.stop()
    }

    static func normalized(_ totalUsage: CGFloat, cores: Int) -> CGFloat {
        min(max(totalUsage / CGFloat(max(cores, 1)), 0), 100)
    }
    
    private func readSnapshot() -> CPUSnapshot {
        let threads = Self.readThreads()
        return CPUSnapshot(
            timestamp:     Date(),
            cores:         coresReader.readCores(),
            threads:       threads,
            cpuTotalUsage: threads.map(\.cpuUsage).reduce(0, +),
            thermalState:  ProcessInfo.processInfo.thermalState
        )
    }
    
}
