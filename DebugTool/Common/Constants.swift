//
//  Constants.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 16.06.2023..
//

import Foundation

struct Constants {
    struct Defaults {
        static let defaultUrlFilename = "NetworkLogs"
        static let defaultLogLimit = 750
    }
    
    struct Values {
        static let numberOfLogs = [250, 500, 750, 1000]
        static let methods = ["GET", "POST", "PATCH", "DELETE"]
    }
    
    struct Strings {
        static let unknown = "n/a"
    }

    struct UserDefaults {
        static let useCustomLogLimit = "useCustomLogLimit"
        static let customLogLimit = "customLogLimit"
        static let standardLogLimit = "standardLogLimit"
        
        static let useCustomFilename = "useCustomFilename"
        static let customFilename = "customFilename"
        static let standardFilename = "standardFilename"
    }
    
    struct Alert {
        static let alertTitle = "Settings are recorded"
        static let alertMessage = "Restart app for proper Debug Tool behaviour using your new settings"
    }
    
    struct Errors {
        static let savingDataToFile = "Unable to save network logs to file"
    }
    
    struct Actions {
        static let initilize = "DT: init..."
        static let configureDT = "DT: configuring debug tool..."
        static let creatingDemoNL = "DT: creating demo network log..."
        static let creatingNL = "DT: creating network log..."
        static let loadingNL = "DT: loading network logs..."
        static let deletingNL = "DT: deleting network logs..."
        static let savingNL = "DT: saving network logs..."
        static let exportingNL = "DT: exporting logs..."
        static let savingSettings = "DT: saving settings..."
    }
}
