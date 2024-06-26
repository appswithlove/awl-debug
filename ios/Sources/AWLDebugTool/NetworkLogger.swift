import Foundation
import SwiftUI

public class NetworkLogger: ObservableObject {
    @Published var didStart = false
    @Published var networkTraffic: [NetworkLog] = []
    @Published var networkLogsLimit: Int = {
        let result = UserDefaults.standard.integer(forKey: Constants.UserDefaults.networkLogsLimit)
        return result <= 0 ? Constants.Defaults.defaultLogLimit : result
    }() {
        didSet {
            UserDefaults.standard.set(networkLogsLimit, forKey: Constants.UserDefaults.networkLogsLimit)
        }
    }
    
    @Published var sortingOrder: Constants.sortingOrder = .ascending
    
    func start() {
        didStart = true
        URLSessionConfiguration.setupSwizzle()
    }
    
    // MARK: - Network logs
    @MainActor
    func appendNetworkLog(requestInfo: AWLDebugURLProtocol.RequestInfo) {
        let log = NetworkLog(id: UUID(),
                             method: requestInfo.method ?? "-",
                             url: requestInfo.url,
                             date: requestInfo.date,
                             duration: requestInfo.duration ?? 0,
                             statusCode: requestInfo.stausCode)
        networkTraffic.append(log)
        cleanNetworkTrafficForLimit()
    }

    @MainActor
    func deleteNetworkLogs() {
        networkTraffic = []
    }
    
    @MainActor
    private func cleanNetworkTrafficForLimit() {
        var networkTraffic = self.networkTraffic
        while networkTraffic.count >= networkLogsLimit {
            networkTraffic.removeFirst()
        }
        self.networkTraffic = networkTraffic
    }
}
