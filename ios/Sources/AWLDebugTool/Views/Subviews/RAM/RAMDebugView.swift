//
//  RAMDebugView.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 12.06.2026.
//

import SwiftUI
import Combine

struct RAMDebugView: View {
    @StateObject private var vm: RAMViewModel

    init(ramMonitor: RAMMonitor) {
        _vm = .init(wrappedValue: RAMViewModel(ramMonitor: ramMonitor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("RAM: \(Self.fmt(vm.current?.footprint ?? 0))", systemImage: "memorychip")

            if let snap = vm.current {
                // App
                Group {
                    row("Footprint", snap.footprint)
                    row("Peak footprint", snap.peakFootprint)
                    row("Resident", snap.resident)
                    row("Available (before jetsam)", snap.available)
                }

                Divider()

                // System
                Group {
                    row("Device total", snap.totalPhysical)
                    row("Free", snap.free)
                    row("Active", snap.active)
                    row("Inactive", snap.inactive)
                    row("Wired", snap.wired)
                    row("Compressed", snap.compressed)
                }
            }

            // history graph
            GeometryReader { geo in
                OneLineView(geo: geo,
                            values: vm.history.map { CGFloat($0.footprint) / 1024 / 1024 },
                            maxValue: 1,
                            capacity: vm.historyCapacity,
                            color: .blue,
                            text: "mb")
            }
            .frame(height: 60)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
    }

    private func row(_ title: String, _ bytes: UInt64) -> some View {
        HStack {
            Text(title)
                .font(.caption)
            Spacer()
            Text(Self.fmt(bytes))
                .font(.caption.monospacedDigit())
        }
    }

    private static func fmt(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

@MainActor
final class RAMViewModel: ObservableObject {
    @Published var current: RAMMonitor.RAMSnapshot?

    @Published var history: [RAMMonitor.RAMSnapshot] = []
    @Published var historyCapacity: Int = 0

    private let ramMonitor: RAMMonitor
    private var cancellables = Set<AnyCancellable>()

    init(ramMonitor: RAMMonitor) {
        self.ramMonitor = ramMonitor
        ramMonitor.snapshotPublisher
            .throttle(
                for: .seconds(1),
                scheduler: RunLoop.main,
                latest: true
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.apply(snap) }
            .store(in: &cancellables)
        if let last = ramMonitor.history.last {
            apply(last)
        }
    }

    private func apply(_ snap: RAMMonitor.RAMSnapshot) {
        history = ramMonitor.history
        historyCapacity = ramMonitor.historyCapacity
        current = snap
    }
}
