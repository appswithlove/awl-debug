//
//  DatesWorker.swift
//  
//
//  Created by Hrvoje Hajduković on 04.09.2025..
//

import Foundation

struct DatesWorker {
    static func extractDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    static func extractTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.dateFormat = "yyyy-MM-dd"
        
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        
        formatter.dateFormat = "HH:mm:ss.SSS"
        
        return formatter
    }()
}
