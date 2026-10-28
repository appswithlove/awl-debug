//
//  CPUMonitor+CoresReader.swift
//  AWLDebugTool
//

import Foundation
import Darwin.Mach

extension CPUMonitor {
    struct CoreLoad {
        public let index: Int
        public let user: Double      // %
        public let system: Double    // %
        public let idle: Double      // %
        public let nice: Double      // %
        public var active: Double { user + system + nice }
    }
    
    class CoresReader {
        // Previous values for the differential per-core calculation
        private var prevCPUInfo: processor_info_array_t?
        private var prevNumCPUInfo: mach_msg_type_number_t = 0
        private var prevNumCPUs: natural_t = 0
        
        deinit {
            freePrevCPUInfo()
        }
        
        /// Per-core load (differential tick calculation)
        func readCores() -> [CoreLoad] {
            var cpuInfo: processor_info_array_t?
            var numCPUInfo: mach_msg_type_number_t = 0
            var numCPUs: natural_t = 0

            let kr = host_processor_info(
                mach_host_self(),
                PROCESSOR_CPU_LOAD_INFO,
                &numCPUs,
                &cpuInfo,
                &numCPUInfo
            )
            guard kr == KERN_SUCCESS, let info = cpuInfo else { return [] }

            var cores: [CoreLoad] = []

            for i in 0..<Int(numCPUs) {
                let offset = Int(CPU_STATE_MAX) * i

                let user   = Double(info[offset + Int(CPU_STATE_USER)])
                let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
                let idle   = Double(info[offset + Int(CPU_STATE_IDLE)])
                let nice   = Double(info[offset + Int(CPU_STATE_NICE)])

                // Delta from the previous measurement
                var dUser = user, dSystem = system, dIdle = idle, dNice = nice

                if let prev = prevCPUInfo, Int(prevNumCPUs) > i {
                    dUser   = user   - Double(prev[offset + Int(CPU_STATE_USER)])
                    dSystem = system - Double(prev[offset + Int(CPU_STATE_SYSTEM)])
                    dIdle   = idle   - Double(prev[offset + Int(CPU_STATE_IDLE)])
                    dNice   = nice   - Double(prev[offset + Int(CPU_STATE_NICE)])
                }

                let total = dUser + dSystem + dIdle + dNice
                guard total > 0 else {
                    cores.append(CoreLoad(index: i, user: 0, system: 0, idle: 100, nice: 0))
                    continue
                }

                cores.append(CoreLoad(
                    index:  i,
                    user:   dUser   / total * 100,
                    system: dSystem / total * 100,
                    idle:   dIdle   / total * 100,
                    nice:   dNice   / total * 100
                ))
            }

            // Update the previous buffer
            freePrevCPUInfo()
            prevCPUInfo    = cpuInfo
            prevNumCPUInfo = numCPUInfo
            prevNumCPUs    = numCPUs

            return cores
        }

        private func freePrevCPUInfo() {
            guard let prev = prevCPUInfo else { return }
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: prev),
                vm_size_t(prevNumCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
            prevCPUInfo = nil
        }
    }
}
