import Foundation
import SwiftUI

public class NetworkLogger: ObservableObject {
    var filtersStorage = FiltersStorage()
    /// Set once in `start(config:)`, before the URL protocol is registered.
    private(set) var config = AWLDebugConfig.NetworkConfig()
    
    @Published var didStart = false
    @Published var networkTraffic: [NetworkLog] = [] {
        didSet {
            trafficLock.lock()
            trafficCopy = networkTraffic
            trafficLock.unlock()
        }
    }
    /// `networkTraffic` for readers off the main thread.
    private var trafficCopy: [NetworkLog] = []
    private let trafficLock = NSLock()
    
    @Published var networkLogsLimit: Int = {
        let result = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKey.networkLogsLimit)
        return result <= 0 ? Constants.Defaults.defaultLogLimit : result
    }() {
        didSet {
            UserDefaults.standard.set(networkLogsLimit, forKey: Constants.UserDefaultsKey.networkLogsLimit)
        }
    }
    
    @Published var sortingOrder: Constants.SortingOrder = {
        if let result = UserDefaults.standard.string(forKey: Constants.UserDefaultsKey.networkLogsSortingOrder),
           let sortingOrder = Constants.SortingOrder(rawValue: result) {
            return sortingOrder
        } else {
            return .ascending
        }
    }() {
        didSet {
            UserDefaults.standard.set(sortingOrder.rawValue, forKey: Constants.UserDefaultsKey.networkLogsSortingOrder)
        }
    }
    
    @Published var isDynamicDataModeOn: Bool = {
        let result = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.networkLogsDynamicData)
        return result
    }() {
        didSet {
            UserDefaults.standard.set(isDynamicDataModeOn, forKey: Constants.UserDefaultsKey.networkLogsDynamicData)
        }
    }
    
    @Published var isEducationalaModeOn: Bool = {
        if UserDefaults.standard.object(forKey: Constants.UserDefaultsKey.networkLogsEducationalMode) == nil {
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.networkLogsEducationalMode)
        }
        return UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.networkLogsEducationalMode)
    }() {
        didSet {
            UserDefaults.standard.set(isEducationalaModeOn, forKey: Constants.UserDefaultsKey.networkLogsEducationalMode)
        }
    }
    
    @Published var methodsAsStaticDict: [String: Bool] = [:]
    var methodsAsDynamicDict: [String: Bool] {
        var methods: [String: Bool] = [:]
        
        for log in networkTraffic {
            let method = log.method
            
            methods[method] = filtersStorage.isMethodFilterActive(for: method)
        }
        
        return methods
    }
    
    var methods: [String: Bool] {
        if isDynamicDataModeOn {
            return methodsAsDynamicDict
        } else {
            return methodsAsStaticDict
        }
    }
    
    @Published var codesAsStaticDict: [Int: Bool] = [:]
    var codesAsDynamicDict: [Int: Bool] {
        var codes: [Int: Bool] = [:]
        
        for log in networkTraffic {
            let code = log.statusCode
            
            codes[code] = filtersStorage.isCodeFilterActive(for: code)
        }
        
        return codes
    }
    
    var codes: [Int: Bool] {
        if isDynamicDataModeOn {
            return codesAsDynamicDict
        } else {
            return codesAsStaticDict
        }
    }
    
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
            methodsAsStaticDict[method.rawValue] = filtersStorage.isMethodFilterActive(for: method.rawValue)
        }
        
        for code in Constants.ResponseCodes.allCases {
            codesAsStaticDict[code.rawValue] = filtersStorage.isCodeFilterActive(for: code.rawValue)
        }
    }
    
    func start(config: AWLDebugConfig.NetworkConfig) {
        self.config = config
        didStart = true
        URLSessionConfiguration.setupSwizzle()
    }
    
    // MARK: - Network logs
    
    @MainActor
    func appendNetworkLog(_ log: NetworkLog) {
        ExtensionState.shared.publish(log)
        networkTraffic.append(log)
        cleanNetworkTrafficForLimit()
    }

    /// The newest `maxEntries` requests, ordered by start time. They are stored when they finish. Any thread.
    func snapshot(maxEntries: Int) -> [NetworkLog] {
        trafficLock.lock()
        let traffic = trafficCopy
        trafficLock.unlock()
        return traffic.suffix(max(maxEntries, 0)).sorted { $0.date < $1.date }
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
        updateAllFilters(for: &methodsAsStaticDict, with: false) { value, key in
            self.filtersStorage.updateMethodFilter(value, for: key)
        }
    }

    func selectAllMethods() {
        updateAllFilters(for: &methodsAsStaticDict, with: true) { value, key in
            self.filtersStorage.updateMethodFilter(value, for: key)
        }
    }

    func deselectAllCodes() {
        updateAllFilters(for: &codesAsStaticDict, with: false) { value, key in
            self.filtersStorage.updateCodeFilter(value, for: key)
        }
    }

    func selectAllCodes() {
        updateAllFilters(for: &codesAsStaticDict, with: true) { value, key in
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
            print("\(LS.logWatermark) Invalid regex: \(error.localizedDescription)")
        }
        return nil
    }
}
