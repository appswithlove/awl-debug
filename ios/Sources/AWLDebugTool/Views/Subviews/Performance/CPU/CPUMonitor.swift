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
        let cpuTotalUsage: CGFloat       // sum % of all threads
        let thermalState: ProcessInfo.ThermalState
        var systemCPU: Double {      // average across all cores
            guard !cores.isEmpty else { return 0 }
            return cores.map(\.active).reduce(0, +) / Double(cores.count)
        }
    }
}

// MARK: - CPUMonitor

final class CPUMonitor {
    lazy private(set) var collection = MonitorCollectionHelper<CPUSnapshot>(interval: 0.5, historyCapacity: 120, queueName: "cpu.monitor", readSnapshot: { [weak self] in
        self?.readSnapshot()
    })
    
    private let coresReader = CoresReader()
    
    init() {
        //
    }
    
    func start() {
        collection.start()
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
