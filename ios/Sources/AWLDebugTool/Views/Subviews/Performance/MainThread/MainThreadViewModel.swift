//
//  MainThreadViewModel.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 13.06.2026.
//

import SwiftUI
import Combine

@MainActor
final class MainThreadViewModel: ObservableObject {
    @Published var history: [MainThreadMonitor.Snapshot] = []
    @Published var historyCapacity: Int = 0

    let monitor: MainThreadMonitor
    private var cancellables = Set<AnyCancellable>()

    init(monitor: MainThreadMonitor) {
        self.monitor = monitor
        monitor.collection.snapshotPublisher
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.apply(snap) }
            .store(in: &cancellables)
        if let last = monitor.collection.history.last {
            apply(last)
        }
    }

    private func apply(_ snap: MainThreadMonitor.Snapshot) {
        history         = monitor.collection.history
        historyCapacity = monitor.collection.historyCapacity
    }
}
