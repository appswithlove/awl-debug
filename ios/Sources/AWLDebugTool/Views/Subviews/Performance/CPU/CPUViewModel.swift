//
//  CPUDebugViewModel.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 13.06.2026.
//

import SwiftUI
import Combine

@MainActor
final class CPUViewModel: ObservableObject {
    @Published var currentCPUTotalUsage: Double = 0
    @Published var currentCores: [CPUMonitor.CoreLoad] = []
    @Published var currentTopThreads: [CPUMonitor.ThreadLoad] = []
    @Published var currentThermalState: TemperatureState?

    @Published var history: [CPUMonitor.CPUSnapshot] = []
    @Published var historyCapacity: Int = 0
    
    private let cpuMonitor: CPUMonitor
    private var cancellables = Set<AnyCancellable>()

    init(cpuMonitor: CPUMonitor) {
        self.cpuMonitor = cpuMonitor
        cpuMonitor.collection.snapshotPublisher
            .throttle(
                for: .seconds(1),
                scheduler: RunLoop.main,
                latest: true
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.apply(snap) }
            .store(in: &cancellables)
        if let last = cpuMonitor.collection.history.last {
            apply(last)
        }
    }

    private func apply(_ snap: CPUMonitor.CPUSnapshot) {
        history = cpuMonitor.collection.history
        historyCapacity = cpuMonitor.collection.historyCapacity
        
        currentCPUTotalUsage = snap.cpuPercent
        currentCores         = snap.cores
        currentTopThreads    = Array(snap.threads.prefix(5))
        currentThermalState  = TemperatureState.from(snap.thermalState)
    }

    enum TemperatureState: CaseIterable {
        case nominal
        case fair
        case serious
        case critical
        
        var color: Color {
            switch self {
            case .nominal:  return .green
            case .fair:     return .yellow
            case .serious:  return .orange
            case .critical: return .red
            }
        }
        
        static func from(_ s: ProcessInfo.ThermalState) -> TemperatureState? {
            switch s {
            case .nominal:  return .nominal
            case .fair:     return .fair
            case .serious:  return .serious
            case .critical: return .critical
            @unknown default: return nil
            }
        }
    }
    
}

