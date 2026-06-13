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
    lazy private(set) var collection = MonitorCollectionHelper<RAMSnapshot>(interval: 0.5, historyCapacity: 120, queueName: "ram.monitor", readSnapshot: { [weak self] in
        self?.readSnapshot()
    })
    
    init() {
        //
    }

    func start() {
        collection.start()
    }

    private func readSnapshot() -> RAMSnapshot {
        let app = Self.readAppMemory()
        let system = Self.readSystemMemory()

        return RAMSnapshot(
            timestamp:     Date(),
            footprint:     app.footprint,
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
