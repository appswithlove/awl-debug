import Foundation
import SwiftUI

public class AWLDebugTool: ObservableObject {
    public static let shared = AWLDebugTool()
    let networkLogger = NetworkLogger()
    let screenRecorder = ScreenRecorderModel()
    let cpuMonitor = CPUMonitor()
    let ramMonitor = RAMMonitor()
    let mainThreadMonitor = MainThreadMonitor()
    let deeplinksManager = DeeplinksManager()
    let sessionManager = SessionManager()
    @MainActor lazy var appLogs = AppLogsStore()

    /// Main initializer.
    ///
    /// If your app uses deep links, see also
    /// `AWLDebugTool.processDeeplinkNotificationIfNeeded()`.
    ///
    /// - Parameters:
    ///   - isScreenRecordingOn: Initial value for screen recording.
    ///     Can be changed later from the debug panel.
    ///   - deeplinks: help to test deeplinks
    ///   - config: Network capture and redaction options.
    public static func start(isScreenRecordingOn: Bool = false, deeplinks: DeepLinkStartModel? = nil, tokens: [AWLDebugTool.TokenDebugModel] = [], config: AWLDebugConfig = AWLDebugConfig()) {
        shared.cpuMonitor.start()
        shared.ramMonitor.start()
        shared.mainThreadMonitor.start()
        
        shared.networkLogger.start(config: config.network)
        Task { @MainActor in
            shared.appLogs.config = config.logs
        }
        shared.screenRecorder.initialise(isScreenRecordingOn: isScreenRecordingOn)
        
        if let deeplinks {
            shared.deeplinksManager.start(with: deeplinks)
        }

        shared.sessionManager.tokens = tokens
    }
}

// MARK: - Logs

public extension AWLDebugTool {
    /// Adds an entry to the Logs module. Safe to call from any thread; `Bearer`/`Basic` credentials are redacted.
    static func log(_ message: String, level: AWLDebugLogLevel = .info, tag: String? = nil, error: Error? = nil) {
        let entry = AppLogEntry(date: Date(), level: level, tag: tag, message: message.redactingCredentials(),
                                errorDescription: error.map { "\(String(reflecting: type(of: $0))): \(String(describing: $0))".redactingCredentials() })
        Task { @MainActor in
            shared.appLogs.append(entry)
        }
    }
}
