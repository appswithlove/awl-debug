//
//  RAMDebugView.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 12.06.2026.
//

import SwiftUI

struct RAMView: View {
    @StateObject private var vm: RAMViewModel

    init(ramMonitor: RAMMonitor) {
        _vm = .init(wrappedValue: RAMViewModel(ramMonitor: ramMonitor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("RAM: \(Self.fmt(vm.current?.footprint ?? 0))", systemImage: "memorychip")

            if let snap = vm.current {
                // App
//                Group {
//                    row("Footprint", snap.footprint)
//                    row("Resident", snap.resident)
//                    row("Available (before jetsam)", snap.available)
//                }

//                Divider()

                // System
                Group {
                    row("Device total", snap.totalPhysical)
//                    row("Free", snap.free)
//                    row("Active", snap.active)
//                    row("Inactive", snap.inactive)
//                    row("Wired", snap.wired)
//                    row("Compressed", snap.compressed)
                }
            }

            // history graph
            GeometryReader { geo in
                OneLineView(geo: geo,
                            values: vm.history.map { CGFloat($0.footprint) / 1024 / 1024 },
                            minValue: 0,
                            capacity: vm.historyCapacity,
                            color: .blue,
                            labelSign: "mb")
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
