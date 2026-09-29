//
//  CPUDebugView.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 11.06.2026.
//

import SwiftUI

struct CPUView: View {
    @StateObject private var vm: CPUViewModel

    init(cpuMonitor: CPUMonitor) {
        _vm = .init(wrappedValue: CPUViewModel(cpuMonitor: cpuMonitor))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(format: "\(LS.Performance.cpu): %.1f%%", vm.currentCPUTotalUsage), systemImage: "cpu")
            
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
//            HStack(spacing: 2) {
//                ForEach(vm.currentCores.indices, id: \.self) { i in
//                    VStack {
//                        RoundedRectangle(cornerRadius: 2)
//                            .fill(vm.currentCores[i].active > 80 ? Color.red : Color.green)
//                            .frame(height: CGFloat(vm.currentCores[i].active) / 100 * 40)
//                    }
//                    .frame(height: 44, alignment: .bottom)
//                }
//            }

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
                            values: vm.history.map { $0.cpuPercent },
                            minValue: 0,
                            capacity: vm.historyCapacity,
                            color: .red,
                            labelSign: "%")
            }
            .frame(height: 60)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
    }
}
