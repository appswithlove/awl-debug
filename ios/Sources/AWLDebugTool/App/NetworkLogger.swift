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
    /// Host filter state per endpoint in the traffic. Reads each endpoint's setting once.
    var endpoints: [String: Bool] {
        var endpoints: [String: Bool] = [:]
        for log in networkTraffic {
            if let endpoint = Self.endpoint(of: log.url), endpoints[endpoint] == nil {
                endpoints[endpoint] = filtersStorage.isEndpointFilterActive(for: endpoint)
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

    /// Finished requests waiting for the next main thread update.
    private var pendingLogs: [NetworkLog] = []
    private var isFlushScheduled = false
    private let pendingLock = NSLock()
    /// Requests that finish within this time reach the list in one main thread update.
    private static let flushInterval: TimeInterval = 0.1

    /// Any thread. Batches the main thread work, so a burst of requests costs a few list updates instead of one each.
    func enqueueNetworkLog(_ log: NetworkLog) {
        pendingLock.lock()
        pendingLogs.append(log)
        let needsFlush = !isFlushScheduled
        isFlushScheduled = true
        pendingLock.unlock()
        guard needsFlush else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flushInterval) { [self] in
            pendingLock.lock()
            let logs = pendingLogs
            pendingLogs = []
            isFlushScheduled = false
            pendingLock.unlock()
            appendNetworkLogs(logs)
        }
    }

    @MainActor
    func appendNetworkLog(_ log: NetworkLog) {
        appendNetworkLogs([log])
    }

    @MainActor
    private func appendNetworkLogs(_ logs: [NetworkLog]) {
        logs.forEach(ExtensionState.shared.publish)
        networkTraffic = Array((networkTraffic + logs).suffix(networkLogsLimit))
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
    
    private static let endpointRegex = try! NSRegularExpression(pattern: Constants.Regex.endpointsPattern)
    
    /// Scheme and host of `url`, the key of the host filter.
    static func endpoint(of url: String) -> String? {
        let nsString = url as NSString
        guard let match = endpointRegex.firstMatch(in: url, range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        return nsString.substring(with: match.range)
    }
}
