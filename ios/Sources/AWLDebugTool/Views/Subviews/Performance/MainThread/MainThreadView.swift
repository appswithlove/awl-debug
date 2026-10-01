//
//  MainThreadDebugView.swift
//  AWLDebugTool
//

import SwiftUI

struct MainThreadView: View {
    @StateObject private var vm: MainThreadViewModel
    @ScaledMetric(relativeTo: .caption2) private var chartHeight: CGFloat = 60

    init(monitor: MainThreadMonitor) {
        _vm = .init(wrappedValue: MainThreadViewModel(monitor: monitor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(latencyTitle, systemImage: "clock.badge.exclamationmark")
            Text(LS.Performance.freezes(count: vm.freezeCount, longestMs: Int(vm.longestFreezeMs)))
                .font(.caption)
                .foregroundStyle(vm.freezeCount > 0 ? Color.statusError : .secondary)

            var hangThreshold: CGFloat = 100 // 100ms
            // Recent hangs from the history window
            let recentHangs = vm.history.filter { $0.latencyMs > hangThreshold} .suffix(5)
            if !recentHangs.isEmpty {
                Divider()
                ForEach(Array(recentHangs.enumerated()), id: \.offset) { _, snap in
                    HStack {
                        Text(snap.timestamp.formatted(
                            .dateTime
                                .hour()
                                .minute()
                                .second()
                                .secondFraction(.fractional(3))
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        Text(verbatim: "\(Int(snap.latencyMs)) ms")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.statusError)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            // Latency history graph (values in ms, always from 0)
            GeometryReader { geo in
                OneLineView( geo: geo,
                             values: vm.history.map { CGFloat($0.latencyMs ) },
                             minValue: 0,
                             capacity: vm.historyCapacity,
                             color: .orange,
                             labelSign: " ms")
            }
            .frame(height: chartHeight)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityHidden(true)
        }
    }

    // MARK: - Helpers

    private var latencyTitle: String {
        guard let snap = vm.history.last else { return "Main thread: —" }
        return "Main thread: \(Int(snap.latencyMs)) ms"
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text(value).font(.caption.monospacedDigit())
        }
    }
}

