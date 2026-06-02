//
//  LS.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 02.06.2026.
//

enum LS {
    
    struct Strings {
        static let appName = "Debug Tool"
        static let unknownValue = "n/a"
        static let emptyString = ""
        static let fatalErrorMsg = "Don't worry be happy."
        static let searchLogs = "Search logs"
        static let tracking = "Track network logs"
        static let trackingInfo = "Add AWLDebugTool.start() into AppDelegate/App init() to enable this."
        static let stopTracking = "stop tracking network logs"
        static let startTracking = "start tracking network logs"
        static let logs = "Logs"
        static let numberOfLogs = "Number of requests: "
        static let emptyListOfLogs = "There is no logs"
        static let filters = "Filters"
    }
    
    struct Headers {
        static let btnClose = "Close"
        static let btnDone = "Done"
        static let logs = "Logs"
        static let userDefaults = "User Defaults"
        static let permissions = "Permissions"
        static let fcm = "FCM push token"
        static let aboutSection = "About"
        static let firebaseActions = "Firebase actions"
        static let screenRecording = "Screen Recording"
        static let settings = "Settings"
        static let requestMethods = "Request Methods"
        static let responseCodes = "Response Codes"
        static let endpoints = "Endpoints"
    }
    
    struct Alert {
        // MARK: - Logs
        static let deleteNLTitle = "Deleting network logs"
        static let deleteNLMessage = "Are you sure you want to delete all network logs?"
        
        // MARK: - UserDefaults
        static let deleteUDTitle = "Deleting UserDefaults data"
        static let deleteUDMessage = "Are you sure you want to delete all UserDefaults data?"
        
        static let btnOK = "OK"
        static let btnCancel = "Cancel"
        static let btnDelete = "Delete"
    }
    
    struct Settings {
        static let logLimit = "Number of logs per session"
        static let exportFileName = "Export file name"
        static let sortingOrder = "Sort network logs"
        static let dynamicData = "Dynamic data"
        static let educationalMode = "Educational mode"
        static let darkMode = "Dark mode"
    }
    
    struct Errors {
        static let savingDataToFile = "Unable to save network logs to file"
    }
    
    struct Actions {
        // MARK: - Logs
        static let showNetworkLogs = "Show network logs"
        static let clearNetworkLogs = "Clear network logs"
        static let exportNetworkLogs = "Export network logs"
        
        // MARK: - UserDefaults
        static let clearAppUserDefaults = "Clear app UserDefaults"
        
        // MARK: - Setting
        static let openAppSettings = "Open app settings"
        
        // MARK: - Screen Recording
        static let screenRecorderToole = "Screen recording"
        static let screenRecorderExportCurrent = "Export current video"
        static let screenRecorderExportLast = "Export last video"
        static let screenRecorderMaxVideoDuration = "Max duration"
        
        // MARK: - Firebase Action
        static let simulateCrash = "Simulate crash"
        static let explicitCrash = " - explicit fatal error"
        static let implicitCrash = " - implicit fatal error"
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
    
    struct Buttons {
        static let deselectAllBtn: String = "DeselectAll"
        static let selectAllBtn: String = "SelectAll"
        static let enable: String = "Enable"
        static let unavailable: String = "Unavailable"
        static let settings: String = "Settings"
    }
    
}
