//
//  Constants.swift
//  DebugTool
//
//  Created by Hrvoje Hajduković on 16.06.2023..
//

import Foundation

struct Constants {
    struct Defaults {
        static let defaultNumberOfLogs = [10, 50, 250, 500, defaultLogLimit, 1000]
        static let defaultLogLimit = 750
    }
    
    struct Strings {
        static let appName = "Debug Tool"
        static let unknownValue = "n/a"
        static let emptyString = ""
        static let fatalErrorMsg = "Don't worry be happy."
        static let searchLogs = "Search logs"
        static let tracking = "Track network logs"
        static let trackingInfo = "Add AWLDebugTool.shared.networkLogger.start() into AppDelegate/App init() to enable this."
        static let stopTracking = "stop tracking network logs"
        static let startTracking = "start tracking network logs"
    }
    
    struct Date {
        static let dateFormatSecondary = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    struct UserDefaults {
        private static let prefix = "AWLDebugTool_"
        static let networkLogsLimit = prefix + "networkLogsLimit"
    }
    
    struct Headers {
        static let btnClose = "Close"
        static let logs = "Logs"
        static let fcm = "FCM push token"
        static let firebaseActions = "Firebase actions"
        static let settings = "Settings"
    }

    struct Alert {
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
        static let play = "play.fill"
        static let pause = "pause.fill"
    }

    struct Settings {
        static let logLimit = "Number of logs per session"
        static let exportFileName = "Export file name"
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
