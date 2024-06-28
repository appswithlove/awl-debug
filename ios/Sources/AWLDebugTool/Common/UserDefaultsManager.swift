//
//  FiltersStorage.swift
//
//
//  Created by Hrvoje Hajduković on 27.06.2024..
//

import SwiftUI

class FiltersStorage: ObservableObject {
    private let methodprefix = "method_"
    private let codeprefix = "code_"

    func getMethodKey(for method: String) -> String {
        return methodprefix + method
    }
    
    func isMethodFilterActive(for method: String) -> Bool {
        let key = getMethodKey(for: method)
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func updateMethodFilter(_ value: Bool, for method: String) {
        UserDefaults.standard.set(value, forKey: getMethodKey(for: method))
    }
    
    func getCodeKey(for code: Int) -> String {
        return codeprefix + String(code)
    }
    
    func isCodeFilterActive(for code: Int) -> Bool {
        let key = getCodeKey(for: code)
        
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func updateCodeFilter(_ value: Bool, for code: Int) {
        UserDefaults.standard.set(value, forKey: getCodeKey(for: code))
    }
}
