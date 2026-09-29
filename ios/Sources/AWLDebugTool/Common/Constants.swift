//
//  Constants.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 16.06.2023..
//

import Foundation

enum Constants {
    struct Defaults {
        static let defaultNumberOfLogs = [10, 50, 250, 500, defaultLogLimit, 1000]
        static let defaultLogLimit = 750
    }
    
    enum SortingOrder: String, CaseIterable, Identifiable {
        case ascending = "Ascending"
        case descending = "Descending"
        
        var id: String { self.rawValue }
    }
    
    enum MaxScreenVideoDuration: Int, CaseIterable, Identifiable {
        case halfMinute = 30
        case oneMinute = 60
        case fiveMinutes = 300
        case tenMinutes = 600
        
        var id: Int { self.rawValue }
        
        var ls: String {
            switch self {
            case .halfMinute: return "30 sec"
            case .oneMinute: return "1 min"
            case .fiveMinutes: return "5 min"
            case .tenMinutes: return "10 min"
            }
        }
    }
    
    struct Values {
        static let enabledBtnOpacity: Double = 1
        static let disabledBtnOpacity: Double = 0.44
    }
    
    struct Regex {
        static let endpointsPattern = #"https?:\/\/[a-zA-Z0-9.-]+(?=\/)"#
    }
    
    struct UserDefaultsKey {
        private static let prefix = "AWLDebugTool_"
        static let networkLogsLimit = prefix + "networkLogsLimit"
        static let networkLogsSortingOrder = prefix + "networkLogsSortingOrder"
        static let networkLogsDynamicData = prefix + "networkLogsDynamicData"
        static let networkLogsEducationalMode = prefix + "networkLogsEducationalMode"
        static let screenRecordingIsOn = prefix + "screenRecordingIsOn"
        static let screenRecordingMaxVideoDuration = prefix + "screenRecordingMaxVideoDuration"
        static let appLogsRecording = prefix + "appLogsRecording"
        static let appLogsLimit = prefix + "appLogsLimit"
    }
    
}
