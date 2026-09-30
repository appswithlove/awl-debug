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
    @MainActor lazy var sessionManager = SessionManager()
    @MainActor lazy var appLogs = AppLogsStore()
    private(set) var appGroupIdentifiers: [String] = []

    /// Main initializer.
    ///
    /// If your app uses deep links, see also
    /// `AWLDebugTool.processDeeplinkNotificationIfNeeded()`.
    ///
    /// - Parameters:
    ///   - deeplinks: help to test deeplinks
    ///   - config: Network capture, redaction, screen recording and session provider options.
    public static func start(deeplinks: DeepLinkStartModel? = nil, config: AWLDebugConfig = AWLDebugConfig()) {
        start(deeplinks: deeplinks, sessionProviders: config.sessionProviders, config: config)
    }

    @available(*, deprecated, message: "Set AWLDebugConfig.screenRecording.isOnByDefault")
    public static func start(isScreenRecordingOn: Bool, deeplinks: DeepLinkStartModel? = nil, config: AWLDebugConfig = AWLDebugConfig()) {
        start(deeplinks: deeplinks, sessionProviders: config.sessionProviders,
              config: config.recordingOnByDefault(isScreenRecordingOn))
    }

    @available(*, deprecated, message: "Pass AWLTokenProvider in AWLDebugConfig.sessionProviders")
    public static func start(isScreenRecordingOn: Bool = false, deeplinks: DeepLinkStartModel? = nil, tokens: [AWLDebugTool.TokenDebugModel], config: AWLDebugConfig = AWLDebugConfig()) {
        start(deeplinks: deeplinks, sessionProviders: tokens.map(\.provider) + config.sessionProviders,
              config: config.recordingOnByDefault(isScreenRecordingOn))
    }

    private static func start(deeplinks: DeepLinkStartModel?, sessionProviders: [any AWLSessionProvider], config: AWLDebugConfig) {
        Task { @MainActor in
            shared.performance.updateSampling()
            shared.sessionManager.providers = sessionProviders
            DebugPanelPresenter.shared.configure(triggers: config.triggers, isAlwaysActive: config.isAlwaysActive)
        }
        
        shared.networkLogger.start(config: config.network)
        ExtensionState.shared.markStarted()
        RemoteReporting.shared.start(config: config.remoteReporting)
        Task { @MainActor in
            shared.appLogs.config = config.logs
        }
        shared.appGroupIdentifiers = config.appGroupIdentifiers
        Task { @MainActor in
            VersionOverlayPresenter.shared.isAvailable = config.showVersionOverlay
            VersionOverlayPresenter.shared.update()
        }
        Task { @MainActor in
            shared.screenRecorder.initialise(config: config.screenRecording)
        }
        
        if let deeplinks {
            shared.deeplinksManager.start(with: deeplinks)
        }
    }
}

private extension AWLDebugConfig {
    func recordingOnByDefault(_ isOn: Bool) -> AWLDebugConfig {
        var config = self
        config.screenRecording.isOnByDefault = config.screenRecording.isOnByDefault || isOn
        return config
    }
}

// MARK: - Logs

public extension AWLDebugTool {
    /// Adds an entry to the Logs module. Safe to call from any thread; `Bearer`/`Basic` credentials and sensitive JSON fields are redacted.
    static func log(_ message: String, level: AWLDebugLogLevel = .info, tag: String? = nil, error: Error? = nil) {
        let entry = AppLogEntry(date: Date(), level: level, tag: tag, message: message.redactingSecrets(),
                                errorDescription: error.map { "\(String(reflecting: type(of: $0))): \(String(describing: $0))".redactingSecrets() })
        Task { @MainActor in
            shared.appLogs.append(entry)
        }
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

    /// Entry point for UIKit apps, instead of `includeDebugTool()`: opens the panel on `AWLDebugConfig.triggers` in all
    /// windows of `scene`. Call it after the scene's window is visible.
    @MainActor static func install(in scene: UIWindowScene, fcmToken: String? = nil) {
        let presenter = DebugPanelPresenter.shared
        presenter.content.fcmToken = fcmToken
        presenter.install(in: scene)
        VersionOverlayPresenter.shared.update(in: scene)
        presenter.applyAppearance(DebugView.AppColorScheme.stored)
    }

    @available(*, deprecated, message: "Set AWLDebugConfig.triggers; .threeTaps is .tripleTap, .userDidTakeScreenshot is .screenshot")
    @MainActor static func install(in scene: UIWindowScene,
                                   fcmToken: String? = nil,
                                   showDebugToolEvents: [DebugToolViewModifier.ShowDebugToolEvents]) {
        DebugPanelPresenter.shared.triggers = Set(showDebugToolEvents.map(\.trigger))
        install(in: scene, fcmToken: fcmToken)
    }
}
