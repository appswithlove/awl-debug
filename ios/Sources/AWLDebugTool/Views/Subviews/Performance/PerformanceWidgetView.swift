//
//  PerformanceWidgetView.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 13.06.2026.
//


import SwiftUI
import Combine

struct PerformanceWidgetView: View {
    @StateObject private var vm: PerformanceWidgetViewModel
    
    init(cpuMonitor: CPUMonitor, ramMonitor: RAMMonitor, mainThreadMonitor: MainThreadMonitor) {
        _vm = .init(wrappedValue: PerformanceWidgetViewModel(cpuMonitor: cpuMonitor, ramMonitor: ramMonitor, mainThreadMonitor: mainThreadMonitor))
    }
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Text("\(ByteCountFormatter.string(fromByteCount: Int64((vm.historyRam.last ?? 0) * 1024 * 1024), countStyle: .memory))")
                    .foregroundStyle(Color.blue)
                Spacer()
                Text("\(vm.historyCPU.last ?? 0, specifier: "%.1f")%")
                    .foregroundStyle(Color.red)
                Spacer()
                Text("\(vm.historyMainThread.last ?? 0, specifier: "%.0f")ms")
                    .foregroundStyle(Color.orange)
            }
            .font(.caption.monospacedDigit())
            
            GeometryReader { geo in
                OneLineView(geo: geo,
                            values: vm.historyRam,
                            minValue: 0,
                            capacity: vm.historyRamCapacity,
                            color: .blue,
                            labelSign: "mb")
            }
            .frame(height: 30)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .cornerRadius(4)
            
            GeometryReader { geo in
                OneLineView(geo: geo,
                            values: vm.historyCPU,
                            minValue: 0,
                            capacity: vm.historyCPUCapacity,
                            color: .red,
                            labelSign: "%")
            }
            .frame(height: 30)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .cornerRadius(4)
            
            GeometryReader { geo in
                OneLineView(geo: geo,
                            values: vm.historyMainThread,
                            minValue: 0,
                            capacity: vm.historyMainThreadCapacity,
                            color: .orange,
                            labelSign: "ms")
            }
            .frame(height: 30)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .cornerRadius(4)
        }
        .frame(width: 200)
        .padding(4)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(4)
    }
    
}

@MainActor
final class PerformanceWidgetViewModel: ObservableObject {
    @Published var historyCPU: [CGFloat] = []
    @Published var historyCPUCapacity: Int = 0
    
    @Published var historyRam: [CGFloat] = []
    @Published var historyRamCapacity: Int = 0
    
    @Published var historyMainThread: [CGFloat] = []
    @Published var historyMainThreadCapacity: Int = 0
    
    private let cpuMonitor: CPUMonitor
    private let ramMonitor: RAMMonitor
    private let mainThreadMonitor: MainThreadMonitor
    private var cancellables = Set<AnyCancellable>()

    init(cpuMonitor: CPUMonitor, ramMonitor: RAMMonitor, mainThreadMonitor: MainThreadMonitor) {
        self.ramMonitor = ramMonitor
        self.cpuMonitor = cpuMonitor
        self.mainThreadMonitor = mainThreadMonitor
        cpuMonitor.collection.snapshotPublisher
            .throttle(
                for: .seconds(3),
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
        historyCPU = cpuMonitor.collection.history.map { $0.cpuTotalUsage }
        historyCPUCapacity = cpuMonitor.collection.historyCapacity
        
        historyRam = ramMonitor.collection.history.map { CGFloat($0.footprint / 1024 / 1024) }
        historyRamCapacity = ramMonitor.collection.historyCapacity
        
        historyMainThread = mainThreadMonitor.collection.history.map { $0.latencyMs }
        historyMainThreadCapacity = mainThreadMonitor.collection.historyCapacity
    }
}

