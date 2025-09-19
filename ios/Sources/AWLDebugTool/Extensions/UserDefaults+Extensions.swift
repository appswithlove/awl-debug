//
//  UserDefaults+Extensions.swift
//  
//
//  Created by Hrvoje Hajduković on 12.09.2025..
//

import Foundation

extension UserDefaults {
    public func clearAppUserDefaults() {
        for key in self.dictionaryRepresentation().keys {
            self.removeObject(forKey: key)
        }
    }
    
    public func clearAll() {
        guard let domainName = Bundle.main.bundleIdentifier else {
            return
        }
        
        removePersistentDomain(forName: domainName)
    }
}
