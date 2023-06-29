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
        static let defaultFilename = "Test1"
        static let defaultNumberOfLogs = [250, 500, 750, 1000]
        static let defaultLogLimit = 750
    }
    
    struct Strings {
        static let appName = "Debug Tool"
        static let unknownValue = "n/a"
        static let emptyString = ""
        static let fatalErrorMsg = "Don't worry be happy."
        static let searchLogs = "Search logs"
    }
    
    struct Date {
        static let dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    }

    struct UserDefaults {
        static let useCustomLogLimit = "useCustomLogLimit"
        static let customLogLimit = "customLogLimit"
        static let standardLogLimit = "standardLogLimit"
        
        static let useCustomFilename = "useCustomFilename"
        static let customFilename = "customFilename"
        static let standardFilename = "standardFilename"
    }
    
    struct Toolbar {
        static let saveAndExit = "Save and exit"
    }

    struct Headers {
        static let logs = "Logs"
        static let fcm = "FCM push token"
        static let firebaseActions = "Firebase actions"
        static let settings = "Settings"
    }

    struct Alert {
        static let saveSettingsTitle = "Settings are recorded"
        static let saveSettingsMessage = "Restart app for proper Debug Tool behaviour using your new settings"

        static let deleteNLTitle = "Deleting network logs"
        static let deleteNLMessage = "Are you sure you want to delete all network logs?"

        static let btnOK = "OK"
        static let btnCancel = "Cancel"
        static let btnDelete = "Delete"
    }
    
    struct Image {
        static let clear = "trash"
        static let export = "square.and.arrow.up"
        static let crash = "pip.remove"
    }

    struct Settings {
        static let standardLogLimit = "Number of logs per session"
        static let customLogLimit = "Custom number of network logs"
        static let customFileName = "Custom file name for network logs"
    }

    struct Errors {
        static let savingDataToFile = "Unable to save network logs to file"
    }
    
    struct Actions {
        static let showNetworkLogs = "Show network logs"
        static let clearNetworkLogs = "Clear network logs"
        static let exportNetworkLogs = "Export network logs"

        static let simulateCrash = "Simulate crash"
        static let explicitCrash = "- explicit fatal error"
        static let implicitCrash = "- implicit fatal error"
    }

    struct Logs {
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
