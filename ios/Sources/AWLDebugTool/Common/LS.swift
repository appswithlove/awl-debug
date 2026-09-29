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
        static let searchLogs = "Search requests"
        static let tracking = "Track network logs"
        static let trackingInfo = "Add AWLDebugTool.start() into AppDelegate/App init() to enable this."
        static let stopTracking = "stop tracking network logs"
        static let startTracking = "start tracking network logs"
        static let logs = "Network"
        static let numberOfLogs = "Number of requests: "
        static let emptyListOfLogs = "No requests yet"
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
        static let endpoints = "Hosts"
        static let session = "Session"
    }
    
    struct Alert {
        // MARK: - Logs
        static let deleteNLTitle = "Delete network logs?"
        static let deleteNLMessage = "All captured requests will be removed."
        
        // MARK: - UserDefaults
        static let deleteUDTitle = "Deleting UserDefaults data"
        static let deleteUDMessage = "Are you sure you want to delete all UserDefaults data?"
        
        static let btnOK = "OK"
        static let btnCancel = "Cancel"
        static let btnDelete = "Delete"
    }
    
    struct Settings {
        static let logLimit = "Number of logs per session"
        static let dynamicData = "Dynamic data"
        static let educationalMode = "Educational mode"
        static let accessibility = "Accessibility"
        static let colorScheme = "Appearance"
        static let appearanceSystem = "System"
        static let appearanceLight = "Light"
        static let appearanceDark = "Dark"
        static let openSettings = "Open settings"
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

        // MARK: - Session
        static let copy = "Copy"
        static let invalidate = "Invalidate"
        static let invalidating = "Invalidating…"
    }
    
    struct Buttons {
        static let deselectAllBtn: String = "Deselect all"
        static let selectAllBtn: String = "Select all"
    }
    
    struct Deeplinks {
        static let sectionTitle = "Deeplinks"
        static let addDeeplink = "Add deeplink"
        static let input = "Enter deeplink"
        static let invalid = "Invalid deeplink"
        static let save = "Save"
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

    struct Network {
        static let copyCurl = "Copy cURL"
        static let copyUrl = "Copy URL"
        static let copyResponse = "Copy response"
        static let share = "Share"
        static let slow = "slow"
        static let noBody = "(no body)"
        static let failed = "Failed"
        static let raw = "Raw"
        static let overview = "Overview"
        static let requestHeaders = "Request Headers"
        static let requestBody = "Request Body"
        static let responseHeaders = "Response Headers"
        static let responseBody = "Response Body"
        static let url = "URL"
        static let method = "Method"
        static let status = "Status"
        static let start = "Start"
        static let duration = "Duration"
        static let requestSize = "Request size"
        static let responseSize = "Response size"
        static let error = "Error"
        static let streamNotCaptured = "(stream, not captured)"
        
        static func redactedCount(_ count: Int) -> String {
            "\(count) values redacted"
        }
        
        static func truncated(_ originalBytes: Int) -> String {
            "(truncated, \(originalBytes) bytes in total)"
        }
    }
    
    struct Permissions {
        static let granted = "Granted"
        static let denied = "Denied"
        static let notDetermined = "Not determined"
        static let limited = "Limited"
        static let provisional = "Provisional"
        static let unknown = "Unknown"
        static let empty = "No permissions declared"
    }

    struct Session {
        static let notSetup = "No tokens configured. Pass tokens in AWLDebugTool.start()."
        static let loggedIn = "Logged in"
        static let loggedOut = "Logged out"
        static let reveal = "Reveal token"
        static let hide = "Hide token"
    }

    struct Performance {
        static let performanceSectionTitle = "Performance"
        static let showPerformanceOverlay = "Show performance overlay"
        static let measure = "Measure performance"
        static let cpu = "CPU"
        static let battery = "Battery"
        static let batteryUnknown = "Battery: n/a"
        static let freeze = "UI freeze"

        static func freezes(count: Int, longestMs: Int) -> String {
            count == 0 ? "\(freeze): none" : "\(freeze): \(count)× (longest \(longestMs) ms)"
        }
    }
}
