//
//  Constants.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 16.06.2023..
//

import Foundation

struct Constants {
    struct Defaults {
        static let defaultFilename = "NetworkLogs"
        static let defaultLogLimit = 750
    }
    
    struct Values {
        static let numberOfLogs = [250, 500, 750, 1000]
        static let methods = ["GET", "POST", "PATCH", "DELETE"]
    }
    
    struct Strings {
        static let unknown = "unknown"
    }

    struct UserDefaults {
        static let useCustomLogLimit = "useCustomLogLimit"
        static let customLogLimit = "customLogLimit"
        static let standardLogLimit = "standardLogLimit"
        
        static let useCustomFilename = "useCustomFilename"
        static let customFilename = "customFilename"
    }
    
    struct Actions {
        static let initilize = "Init..."
        static let configureDT = "Configuring network log..."
        static let creatingDemoNL = "Creating demo network log..."
        static let creatingNL = "Creating network log..."
        static let loadingNL = "Loading network logs..."
        static let deletingNL = "Deleting network logs..."
        static let savingNL = "Saving network logs..."
        static let exportingNL = "Exporting logs..."
        static let savingSettings = "Saving settings..."
    }
    
    struct Alert {
        static let alertTitle = "Alert title"
        static let alertMessage = "Alert message"
    }
    
    struct Errors {
        static let savingDataToFile = "Unable to save network logs to file"
    }
}
