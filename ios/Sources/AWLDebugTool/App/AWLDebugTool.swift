import Foundation
import SwiftUI

public class AWLDebugTool: ObservableObject {
    public static let shared = AWLDebugTool()
    let networkLogger = NetworkLogger()
    let screenRecorder = ScreenRecorderModel()
    let cpuMonitor = CPUMonitor()
    let ramMonitor = RAMMonitor()
    let mainThreadMonitor = MainThreadMonitor()
    let batteryMonitor = BatteryMonitor()
    @MainActor lazy var performance = PerformanceController(monitors: self)
    let deeplinksManager = DeeplinksManager()
    let sessionManager = SessionManager()

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
        Task { @MainActor in
            shared.performance.updateSampling()
        }
        
        shared.networkLogger.start(config: config.network)
        shared.screenRecorder.initialise(isScreenRecordingOn: isScreenRecordingOn)
        
        if let deeplinks {
            shared.deeplinksManager.start(with: deeplinks)
        }

        shared.sessionManager.tokens = tokens
    }
}

