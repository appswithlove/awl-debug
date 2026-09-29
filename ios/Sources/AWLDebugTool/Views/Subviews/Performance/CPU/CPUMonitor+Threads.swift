//
//  CPUMonitor+Threads.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 11.06.2026.
//

import Foundation
import Darwin.Mach

// The *_COUNT C macros use sizeof(struct) and are not imported into Swift
private let THREAD_BASIC_INFO_COUNT = mach_msg_type_number_t(
    MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size
)

extension QualityOfService {
    init(_ qosClass: qos_class_t) {
        switch qosClass {
        case QOS_CLASS_USER_INTERACTIVE: self = .userInteractive
        case QOS_CLASS_USER_INITIATED:   self = .userInitiated
        case QOS_CLASS_UTILITY:          self = .utility
        case QOS_CLASS_BACKGROUND:       self = .background
        default:                         self = .default
        }
    }
    
    var ls: String {
        switch self {
        case .userInteractive: return "userInteractive"
        case .userInitiated: return "userInitiated"
        case .utility: return "utility"
        case .background: return "background"
        default: return "default"
        }
    }
}

// MARK: - Data Models

extension CPUMonitor {
    /// Load of a single thread
    struct ThreadLoad {
        public let id: UInt32
        public let name: String      // empty string if the thread has no name
        public let cpuUsage: CGFloat  // %
        public let userTime: TimeInterval
        public let systemTime: TimeInterval
        public let qos: QualityOfService
    }
    
}

extension CPUMonitor {
    /// CPU% of every thread + name + QoS
    static func readThreads() -> [ThreadLoad] {
        var threads: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let kr = task_threads(mach_task_self_, &threads, &threadCount)
        guard kr == KERN_SUCCESS, let threadList = threads else { return [] }

        var result: [ThreadLoad] = []

        for i in 0..<Int(threadCount) {
            let thread = threadList[i]

            // thread_basic_info
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)
            let kr2 = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(THREAD_BASIC_INFO_COUNT)) {
                    thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            guard kr2 == KERN_SUCCESS else { continue }
            guard info.flags & TH_FLAGS_IDLE == 0 else { continue }   // skip idle threads

            // Thread name and QoS (a mach port cannot be cast to pthread_t —
            // it must be converted via pthread_from_mach_thread_np)
            var name = ""
            var qos: QualityOfService = .default
            if let pthread = pthread_from_mach_thread_np(thread) {
                var nameBuf = [CChar](repeating: 0, count: 64)
                if pthread_getname_np(pthread, &nameBuf, 64) == 0 {
                    name = String(cString: nameBuf)
                }
                var qosClass = qos_class_t(rawValue: 0)
                if pthread_get_qos_class_np(pthread, &qosClass, nil) == 0 {
                    qos = QualityOfService(qosClass)
                }
            }

            let cpuUsage = Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            let userTime   = TimeInterval(info.user_time.seconds) + TimeInterval(info.user_time.microseconds) / 1_000_000
            let systemTime = TimeInterval(info.system_time.seconds) + TimeInterval(info.system_time.microseconds) / 1_000_000

            result.append(ThreadLoad(
                id:         thread,
                name:       name,
                cpuUsage:   cpuUsage,
                userTime:   userTime,
                systemTime: systemTime,
                qos:        qos
            ))
        }

        // Free the thread list
        vm_deallocate(
            mach_task_self_,
            vm_address_t(bitPattern: threadList),
            vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size)
        )

        return result.sorted { $0.cpuUsage > $1.cpuUsage }
    }


}
