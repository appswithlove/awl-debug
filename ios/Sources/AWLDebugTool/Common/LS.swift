//
//  LS.swift
//  AWLDebugTool
//
//  Created by Yanis Plumit on 02.06.2026.
//

enum LS {
    static let logWatermark = "[AWL Debug Tool]"
    
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
        static let colorScheme = "Color scheme"
        static let fontSize = "Font size"
        static let fontSizeInfoButton = "How to scale on device"
        static let fontSizeInfoMessage = """
            Scale font only
            Settings → Accessibility → Display & Text Size → Larger Text

            Scale font and images
            Settings → Display & Brightness → Display Zoom → Larger Text → Set
            (Settings → Developer → Display Zoom → Larger Text → Set)
            """
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
    
    struct Buttons {
        static let deselectAllBtn: String = "DeselectAll"
        static let selectAllBtn: String = "SelectAll"
        static let enable: String = "Enable"
        static let unavailable: String = "Unavailable"
        static let settings: String = "Settings"
    }
    
    struct Deeplinks {
        static let sectionTitle = "Deeplinks"
        static let addDeeplink = "Add deeplink"
        static let empty = "No deeplinks configured"
        static let fireNow = "Fire now"
        static let schedule = "Schedule & close app"
        static let delay = "Delay"
        static let seconds = "s"
        static let whileActive = "While app is active"
        static let coldStart = "Cold start (via notification)"
        static let coldStartFooter = "A local notification will fire after the delay. Close the app after scheduling to test cold start. Note: may be suppressed in Focus mode."
        static let titlePlaceholder = "Title"
        static let urlPlaceholder = "myapp://path"
        static let notificationTitle = "Deeplink"
        static let errorPermissionDenied = "Notification permission is required to fire deeplinks with delay."
        static let errorSchedulingFailed = "Failed to schedule notification."

        static func scheduledSuccess(_ seconds: Int) -> String {
            "Scheduled in \(seconds)s. You can close the app now."
        }
    }

    struct Performance {
        static let performanceSectionTitle = "Performance"
        static let showPerformanceOverlay = "Show performance overlay"
    }
}
