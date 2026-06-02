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
    
    struct Date {
        static let dateFormatSecondary = "yyyy-MM-dd HH:mm:ss.SSS"
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
    
    struct Image {
        static let clear = "trash"
        static let export = "square.and.arrow.up"
        static let crash = "pip.remove"
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let sortingOrder = "arrow.up.arrow.down"
        static let filtersUnset = "line.3.horizontal.decrease.circle"
        static let filtersSet = "line.3.horizontal.decrease.circle.fill"
        static let chevronUp = "chevron.up"
        static let chevronDown = "chevron.down"
        static let gear = "gear"
    }
    
    struct UserDefaults {
        private static let prefix = "AWLDebugTool_"
        static let networkLogsLimit = prefix + "networkLogsLimit"
        static let networkLogsSortingOrder = prefix + "networkLogsSortingOrder"
        static let networkLogsDynamicData = prefix + "networkLogsDynamicData"
        static let networkLogsEducationalMode = prefix + "networkLogsEducationalMode"
        static let screenRecordingIsOn = prefix + "screenRecordingIsOn"
        static let screenRecordingMaxVideoDuration = prefix + "screenRecordingMaxVideoDuration"
    }
    
}
