//
//  RAMMonitor+Reader.swift
//  AWLDebugTool
//

import Foundation
import Darwin.Mach
import os

// The *_COUNT C macros use sizeof(struct) and are not imported into Swift
private let TASK_VM_INFO_COUNT = mach_msg_type_number_t(
    MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
)
private let HOST_VM_INFO64_COUNT = mach_msg_type_number_t(
    MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
)

extension RAMMonitor {

    /// App memory via task_vm_info: phys_footprint + resident size
    static func readAppMemory() -> (footprint: UInt64, resident: UInt64) {
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(TASK_VM_INFO_COUNT)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0) }
        return (info.phys_footprint, info.resident_size)
    }

    /// System-wide memory via host_statistics64 (page counts -> bytes)
    static func readSystemMemory() -> (free: UInt64, active: UInt64, inactive: UInt64, wired: UInt64, compressed: UInt64) {
        var stats = vm_statistics64_data_t()
        var count = HOST_VM_INFO64_COUNT
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(HOST_VM_INFO64_COUNT)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0, 0, 0, 0) }

        let pageSize = UInt64(vm_page_size)
        return (
            free:       UInt64(stats.free_count) * pageSize,
            active:     UInt64(stats.active_count) * pageSize,
            inactive:   UInt64(stats.inactive_count) * pageSize,
            wired:      UInt64(stats.wire_count) * pageSize,
            compressed: UInt64(stats.compressor_page_count) * pageSize
        )
    }
}
