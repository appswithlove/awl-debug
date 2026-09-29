//
//  RAMDebugViewModel.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 13.06.2026.
//

import SwiftUI
import Combine

@MainActor
final class RAMViewModel: ObservableObject {
    @Published var current: RAMMonitor.RAMSnapshot?

    @Published var history: [RAMMonitor.RAMSnapshot] = []
    @Published var historyCapacity: Int = 0

    private let ramMonitor: RAMMonitor
    private var cancellables = Set<AnyCancellable>()

    init(ramMonitor: RAMMonitor) {
        self.ramMonitor = ramMonitor
        ramMonitor.collection.snapshotPublisher
            .throttle(
                for: .seconds(2),
                scheduler: RunLoop.main,
                latest: true
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.apply(snap) }
            .store(in: &cancellables)
        if let last = ramMonitor.collection.history.last {
            apply(last)
        }
    }

    private func apply(_ snap: RAMMonitor.RAMSnapshot) {
        history = ramMonitor.collection.history
        historyCapacity = ramMonitor.collection.historyCapacity
        current = snap
    }
}
