import Foundation
import SwiftUI

public class NetworkLogger: ObservableObject {
    var filtersStorage = FiltersStorage()
    
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
    
    @Published var sortingOrder: Constants.SortingOrder = {
        if let result = UserDefaults.standard.string(forKey: Constants.UserDefaults.networkLogsSortingOrder),
           let sortingOrder = Constants.SortingOrder(rawValue: result) {
            return sortingOrder
        } else {
            return .ascending
        }
    }() {
        didSet {
            UserDefaults.standard.set(sortingOrder.rawValue, forKey: Constants.UserDefaults.networkLogsSortingOrder)
        }
    }
    @Published var methods: [String: Bool] = [:]
    @Published var codes: [Int: Bool] = [:]
    @Published var endpointsHasChanged: Bool = false
    
    var endpoints: [String: Bool] {
        
        let regex = try! NSRegularExpression(pattern: Constants.Regex.endpointsPattern, options: [])
        
        var endpoints: [String: Bool] = [:]
        
        for log in networkTraffic {
            let matches = findFirstMatch(in: log.url, with: Constants.Regex.endpointsPattern)
            
            if let matches = matches {
                endpoints[matches] = filtersStorage.isEndpointFilterActive(for: matches)
            }
        }
         
        return endpoints
    }

    init() {
        for method in Constants.RequestMethod.allCases {
            methods[method.rawValue] = filtersStorage.isMethodFilterActive(for: method.rawValue)
        }
        
        for code in Constants.ResponseCodes.allCases {
            codes[code.rawValue] = filtersStorage.isCodeFilterActive(for: code.rawValue)
        }
    }
    
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
    
    // MARK: - Filters
    
    func deselectAllMethods() {
        updateAllFilters(for: &methods, with: false) { value, key in
            self.filtersStorage.updateMethodFilter(value, for: key)
        }
    }

    func selectAllMethods() {
        updateAllFilters(for: &methods, with: true) { value, key in
            self.filtersStorage.updateMethodFilter(value, for: key)
        }
    }

    func deselectAllCodes() {
        updateAllFilters(for: &codes, with: false) { value, key in
            self.filtersStorage.updateCodeFilter(value, for: key)
        }
    }

    func selectAllCodes() {
        updateAllFilters(for: &codes, with: true) { value, key in
            self.filtersStorage.updateCodeFilter(value, for: key)
        }
    }
    
    func updateAllFilters<T>(for dictionary: inout [T: Bool], with value: Bool, updateFilter: (Bool, T) -> Void) {
        dictionary.keys.forEach { key in
            updateFilter(value, key)
            dictionary[key] = value
        }
    }
    
    func deselectAllEndpoints() {
        updateAllEndpoints(to: false)
    }

    func selectAllEndpoints() {
        updateAllEndpoints(to: true)
    }
    
    func updateAllEndpoints(to isSelected: Bool) {
        for endpoint in endpoints {
            self.filtersStorage.updateEndpointFilter(isSelected, for: endpoint.key)
            self.endpointsHasChanged = true
        }
    }
    
    // MARK: - Regex
    
    func findFirstMatch(in text: String, with pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsString.length)) {
                return nsString.substring(with: match.range)
            }
        } catch let error {
            print("Invalid regex: \(error.localizedDescription)")
        }
        return nil
    }
}
