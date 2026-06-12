//
//  CPUDebugView.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 11.06.2026.
//

import SwiftUI
import Combine

struct CPUDebugView: View {
    @StateObject private var vm: CPUViewModel

    init(cpuMonitor: CPUMonitor) {
        _vm = .init(wrappedValue: CPUViewModel(cpuMonitor: cpuMonitor))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(format: "CPU usage: %.1f%%", vm.currentCPUTotalUsage), systemImage: "cpu")
            
            HStack {
                Image(systemName: "thermometer")
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: CPUViewModel.TemperatureState.allCases.map { $0.color },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 20)
                .overlay {
                    HStack {
                        ForEach(CPUViewModel.TemperatureState.allCases, id: \.self) { t in
                            if t == vm.currentThermalState {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        Circle()
                                            .stroke(.black)
                                    }
                            } else {
                                Spacer()
                            }
                        }
                    }
                }
            }

            // Per-core spark bars
            HStack(spacing: 2) {
                ForEach(vm.currentCores.indices, id: \.self) { i in
                    VStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(vm.currentCores[i].active > 80 ? Color.red : Color.green)
                            .frame(height: CGFloat(vm.currentCores[i].active) / 100 * 40)
                    }
                    .frame(height: 44, alignment: .bottom)
                }
            }

            // Top threads
            ForEach(vm.currentTopThreads, id: \.id) { t in
                VStack(alignment: .leading) {
                    HStack {
                        Text(t.name.isEmpty ? "thread-\(t.id)" : t.name)
                            .font(.caption).lineLimit(1)
                        
                        Spacer()
                        Text(String(format: "%.1f%%", t.cpuUsage))
                            .font(.caption.monospacedDigit())
                    }
                    Text("\(t.qos.ls); Time: user=\(t.userTime.formatted(.number.precision(.fractionLength(1)))) system=\(t.systemTime.formatted(.number.precision(.fractionLength(1))))")
                        .font(.caption).lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            
            // history graph
            GeometryReader { geo in
                OneLineView(geo: geo,
                            values: vm.history.map { CGFloat($0.cpuTotalUsage) },
                            maxValue: 10,
                            capacity: vm.historyCapacity,
                            color: .green,
                            text: "%")
            }
            .frame(height: 60)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
    }
}

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
        cpuMonitor.snapshotPublisher
            .throttle(
                for: .seconds(1),
                scheduler: RunLoop.main,
                latest: true
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.apply(snap) }
            .store(in: &cancellables)
        if let last = cpuMonitor.history.last {
            apply(last)
        }
    }

    private func apply(_ snap: CPUMonitor.CPUSnapshot) {
        history = cpuMonitor.history
        historyCapacity = cpuMonitor.historyCapacity
        
        currentCPUTotalUsage = snap.cpuTotalUsage
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

