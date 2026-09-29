//
//  NetworkReachabilityManager.swift
//
//
//  Created by Hrvoje Hajduković on 19.09.2025..
//

import Network
import SwiftUI

class NetworkReachabilityManager: ObservableObject {
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "Monitor")

    @Published public internal(set) var isConnected = true
    
    var connectionStatusIcon: (name: String, color: Color)  {
        if isConnected {
            return ("wifi", .blue)
        } else {
            return ("wifi.slash", .gray)
        }
    }

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
