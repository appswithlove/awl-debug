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
        shared.screenRecorder.initialise(isScreenRecordingOn: isScreenRecordingOn)
        
        if let deeplinks {
            shared.deeplinksManager.start(with: deeplinks)
        }

        shared.sessionManager.tokens = tokens
    }
}

// MARK: - Panel

public extension AWLDebugTool {
    /// Whether the debug panel is shown.
    @MainActor static var isOpen: Bool {
        DebugPanelPresenter.shared.isOpen
    }

    /// Opens the debug panel above everything the app shows, including sheets and full-screen covers.
    /// Does nothing while it is open.
    @MainActor static func open() {
        DebugPanelPresenter.shared.open()
    }

    /// Closes the debug panel. Does nothing while it is closed.
    @MainActor static func close() {
        DebugPanelPresenter.shared.close()
    }

    @MainActor static func toggle() {
        isOpen ? close() : open()
    }

    /// Entry point for UIKit apps, instead of `includeDebugTool()`: opens the panel on the given events in all
    /// windows of `scene`. Call it after the scene's window is visible.
    @MainActor static func install(in scene: UIWindowScene,
                                   fcmToken: String? = nil,
                                   showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents] = [.threeTaps]) {
        let presenter = DebugPanelPresenter.shared
        presenter.events = showDebugToolEvents
        presenter.content.fcmToken = fcmToken
        presenter.install(in: scene)
    }
}
