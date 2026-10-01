//
//  FiltersStorage.swift
//
//

import SwiftUI

class FiltersStorage: ObservableObject {
    private let methodPrefix = "method_"
    private let codePrefix = "code_"
    private let endpointPrefix = "endpoint_"
    
    @AppStorage("isRequestMethodsContentShown")
    var isRequestMethodsContentShown: Bool = true
    
    @AppStorage("isResponseCodesContentShown")
    var isResponseCodesContentShown: Bool = true
    
    @AppStorage("isEndpointsContentShown")
    var isEndpointsContentShown: Bool = true
    
    // MARK: - Methods
    
    func getMethodKey(for method: String) -> String {
        return getKey(prefix: methodPrefix, value: method)
    }
    
    func isMethodFilterActive(for method: String) -> Bool {
        return isFilterActive(forKey: getMethodKey(for: method))
    }
    
    func updateMethodFilter(_ value: Bool, for method: String) {
        updateFilter(value, forKey: getMethodKey(for: method))
    }
    
    // MARK: - Codes
    
    func getCodeKey(for code: Int) -> String {
        return getKey(prefix: codePrefix, value: code)
    }
    
    func isCodeFilterActive(for code: Int) -> Bool {
        return isFilterActive(forKey: getCodeKey(for: code))
    }
    
    func updateCodeFilter(_ value: Bool, for code: Int) {
        updateFilter(value, forKey: getCodeKey(for: code))
    }
    
    // MARK: - Endpoints
    
    func getEndpointKey(for endpoint: String) -> String {
        return getKey(prefix: endpointPrefix, value: endpoint)
    }
    
    func isEndpointFilterActive(for endpoint: String) -> Bool {
        return isFilterActive(forKey: getEndpointKey(for: endpoint))
    }
    
    func updateEndpointFilter(_ value: Bool, for endpoint: String) {
        updateFilter(value, forKey: getEndpointKey(for: endpoint))
    }
    
    // MARK: - Helper Methods
    
    private func getKey(prefix: String, value: CustomStringConvertible) -> String {
        return prefix + String(describing: value)
    }
    
    private func isFilterActive(forKey key: String) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private func updateFilter(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
