//
//  NetworkReachabilityManager.swift
//
//

import Network
import SwiftUI

class NetworkReachabilityManager: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "Monitor")

    @Published public internal(set) var isConnected = true

    public init() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                withAnimation {
                    self.isConnected = path.status == .satisfied
                }
            }
        }
        networkMonitor.start(queue: workerQueue)
    }
}
