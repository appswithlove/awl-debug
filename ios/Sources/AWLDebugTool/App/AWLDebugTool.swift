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

    /// Main initializer.
    ///
    /// If your app uses deep links, see also
    /// `AWLDebugTool.processDeeplinkNotificationIfNeeded()`.
    ///
    /// - Parameters:
    ///   - isScreenRecordingOn: Initial value for screen recording.
    ///     Can be changed later from the debug panel.
    ///   - deeplinkHandler: Custom deep-link handler. If `nil`,
    ///     URLs are opened using `UIApplication.shared.open(_:)`.
    ///     This is sufficient when using custom URL schemes.
    public static func start(isScreenRecordingOn: Bool = false, deeplinks: [AWLDeeplink] = [], deeplinkHandler: ((URL) -> Void)? = nil) {
        shared.cpuMonitor.start()
        shared.ramMonitor.start()
        shared.mainThreadMonitor.start()
        
        shared.networkLogger.start()
        shared.screenRecorder.initialise(isScreenRecordingOn: isScreenRecordingOn)
        
        shared.deeplinksManager.developerDeeplinks = deeplinks
        shared.deeplinksManager.deeplinkHandler = deeplinkHandler
    }
}
