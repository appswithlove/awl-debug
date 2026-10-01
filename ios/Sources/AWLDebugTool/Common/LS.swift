//
//  LS.swift
//  AWLDebugTool
//

enum LS {
    static let logWatermark = "[AWL Debug Tool]"

    enum Panel {
        /// VoiceOver value of a start-page module that records or measures (the green dot).
        static let active = "On"
        /// Shown after an extension row copied its value.
        static let copied = "Copied"
        /// VoiceOver hint of an extension row that copies its value.
        static let copyHint = "Copies the value."
    }
    
    struct Strings {
        static let appName = "AWL Debug"
        static let unknownValue = "n/a"
        static let emptyString = ""
        static let searchLogs = "Search requests"
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
        static let permissions = "Permissions"
        static let fcm = "FCM Push Token"
        static let aboutSection = "App Info"
        static let testCrashes = "Test Crashes"
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
        static let clearNetworkLogs = "Clear network logs"
        static let exportNetworkLogs = "Export network logs"
        
        // MARK: - Setting
        static let openAppSettings = "Open app settings"
        
        // MARK: - Screen Recording
        static let screenRecorderToole = "Screen recording"
        static let screenRecorderExportCurrent = "Export current recording"
        static let screenRecorderExportLast = "Export last recording"
        static let screenRecorderMaxVideoDuration = "Max duration"
        static let screenRecorderLastAvailable = "Last recording available (%@)"
        static let screenRecorderEmpty = "No recording yet"
        static let screenRecorderWarning = "Recordings can contain personal data. Secure text fields are masked."

        // MARK: - Session
        static let copy = "Copy"
        static let invalidate = "Invalidate"
        static let invalidating = "Invalidating…"
    }
    
    struct Buttons {
        static let deselectAllBtn: String = "Deselect all"
        static let selectAllBtn: String = "Select all"
        /// VoiceOver values of the collapsible filter groups.
        static let expanded = "Expanded"
        static let collapsed = "Collapsed"
    }
    
    struct Deeplinks {
        static let sectionTitle = "Deeplinks"
        static let predefined = "Predefined"
        static let saved = "Saved"
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
        static let newestFirst = "Newest first"
        static let oldestFirst = "Oldest first"
        
        static func redactedCount(_ count: Int) -> String {
            "\(count) values redacted"
        }
        
        static func truncated(_ originalBytes: Int) -> String {
            "(truncated, \(originalBytes) bytes in total)"
        }
    }
    
    struct AppLogs {
        static let title = "Logs"
        static let search = "Search logs"
        static let empty = "No logs yet"
        static let export = "Export logs"
        static let clear = "Clear logs"
        static let limit = "Number of logs per session"
        static let record = "Record logs"
        static let copied = "Copied"
        static let allLevels = "all"
        static let filterLevels = "Levels"
        static let filterSearch = "Search"
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

    struct TestCrashes {
        static let runtime = "Simulate crash - Runtime exception"
        static let indexOutOfBounds = "Simulate crash - Index out of bounds"
        static let confirmTitle = "Crash the app now?"
        static let confirm = "Crash"
        static let message = "AWL Debug test crash"
    }

    struct AppInfo {
        static let app = "App"
        static let version = "Version"
        static let build = "Build"
        static let device = "Device"
        static let os = "OS"
        static let locale = "Locale"
        static let time = "Time"
        static let internet = "Internet"
        static let online = "Online"
        static let offline = "Offline"
    }

    struct ClearData {
        static let title = "Clear App Data"
        static let button = "Clear app data"
        static let confirmTitle = "Clear app data?"
        static let confirmMessage = "The selected data will be deleted. AWL Debug settings are kept."
        static let userDefaults = "UserDefaults"
        static let keychain = "Keychain"
        static let files = "Files"
        static let cookies = "Cookies and caches"
        static let confirm = "Clear"
        static let done = "Data cleared. Close the app to start fresh."
        static let closeApp = "Close app"
    }

    struct VersionOverlay {
        static let toggle = "Show version overlay"
    }

    struct Session {
        static let loggedIn = "Logged in"
        static let loggedOut = "Logged out"
        static let reveal = "Reveal token"
        static let hide = "Hide token"
        static let edit = "Edit"
        static let delete = "Delete"
        static let login = "Login"
        static let refresh = "Refresh"
        static let logout = "Logout"
        static let pastePlaceholder = "Paste token"
        static let confirm = "Confirm"
        static let cancel = "Cancel"
        static let deleteTitle = "Delete token?"

        static func editTitle(_ label: String) -> String {
            "Edit token - \(label)"
        }

        static func deleteMessage(_ label: String) -> String {
            "This will remove the access token for \"\(label)\" and break the current session."
        }

        static func actionFailed(_ message: String) -> String {
            "Action failed: \(message)"
        }
    }

    struct Performance {
        static let performanceSectionTitle = "Performance"
        static let showPerformanceOverlay = "Show performance overlay"
        static let measure = "Measure performance"
        static let cpu = "CPU"
        static let ram = "RAM"
        static let collecting = "Collecting data..."
        static let battery = "Battery"
        static let batteryUnknown = "Battery: n/a"
        static let freeze = "UI freeze"
        static let thermalState = "Thermal state"

        static func freezes(count: Int, longestMs: Int) -> String {
            count == 0 ? "\(freeze): none" : "\(freeze): \(count)× (longest \(longestMs) ms)"
        }
    }
}
