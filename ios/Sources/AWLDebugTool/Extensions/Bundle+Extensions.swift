//
//  Bundle+Extensions.swift
//  
//

import Foundation

extension Bundle {
    func hasPlistKeys(_ keys: [String], requireAll: Bool = false) -> Bool {
        guard let dict = infoDictionary else { return false }
        
        if requireAll {
            return keys.allSatisfy { dict[$0] != nil }
        } else {
            return keys.contains { dict[$0] != nil }
        }
    }
}
