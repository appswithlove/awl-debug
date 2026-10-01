import SwiftUI
import UIKit

/// Shows the panel in a window of its own above everything the app presents, so it opens the same way over
/// sheets, full-screen covers and alerts and never disturbs their state.
@MainActor
final class DebugPanelPresenter: NSObject {
    static let shared = DebugPanelPresenter()

    /// What the host passed to `includeDebugTool` or `install(in:)`; read while the panel is open.
    final class Content: ObservableObject {
        @Published var fcmToken: String?
        var customView: (() -> any View)?
    }

    let content = Content()
    var triggers: Set<AWLDebugTrigger> = [.threeFingerTap] {
        didSet { updateRecognizers() }
    }
    var isAlwaysActive = false
    /// Triggers that AWLDebugFeedback or a registered extension section handles; they do not open the panel.
    var feedbackTriggers: () -> Set<AWLDebugTrigger> = {
        (FeedbackBridge.current?.triggers ?? []).union(ExtensionSectionRegistry.shared.claimedTriggers)
    }
    private var warnedConflicts: Set<AWLDebugTrigger> = []

    private var window: UIWindow?
    private weak var previousKeyWindow: UIWindow?
    private var installedRecognizers: [ObjectIdentifier: [AWLDebugTrigger: UITapGestureRecognizer]] = [:]
    private let gestureDelegate = SimultaneousGestureDelegate()

    var isOpen: Bool {
        window != nil
    }

    private override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(userDidTakeScreenshot),
                           name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        center.addObserver(self, selector: #selector(deviceDidShake), name: PanelShakeDetector.notification, object: nil)
    }

    func configure(triggers: Set<AWLDebugTrigger>, isAlwaysActive: Bool) {
        self.triggers = triggers
        self.isAlwaysActive = isAlwaysActive
    }

    @objc private func userDidTakeScreenshot() {
        trigger(.screenshot)
    }

    @objc private func deviceDidShake() {
        trigger(.shake)
    }

    /// Opens the panel if `trigger` is configured and the tool is activated. Never closes it.
    func trigger(_ trigger: AWLDebugTrigger) {
        if opensPanel(on: trigger) {
            open()
        }
    }

    /// `true` when `trigger` is configured, the tool is activated and no extension claims the trigger.
    /// A claimed trigger logs a warning once.
    func opensPanel(on trigger: AWLDebugTrigger) -> Bool {
        guard triggers.contains(trigger), isAlwaysActive || AWLDebugTool.isActivated else {
            return false
        }
        if feedbackTriggers().contains(trigger) {
            if warnedConflicts.insert(trigger).inserted {
                AWLDebugTool.log("Trigger \(trigger) is configured for the panel and claimed by an extension; it does not open the panel.",
                                 level: .warn, tag: "AWLDebug")
            }
            return false
        }
        return true
    }

    func open() {
        guard window == nil, let scene = Self.activeScene() else {
            return
        }
        previousKeyWindow = scene.keyWindow

        let host = UIHostingController(rootView: DebugPanelRootView(content: content))
        // Closing is explicit (Close button or `close()`), so scrolling a list never dismisses the panel.
        host.isModalInPresentation = true
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        let root = UIViewController()
        root.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.accessibilityIdentifier = RecordingFrameRenderer.sdkWindowIdentifier
        window.windowLevel = .alert + 1
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        root.present(host, animated: true)
    }

    /// `completion` runs once the panel is gone, right away if it is closed.
    func close(completion: (() -> Void)? = nil) {
        guard let window = window else {
            completion?()
            return
        }
        self.window = nil
        let previousKeyWindow = previousKeyWindow
        window.rootViewController?.dismiss(animated: true) {
            window.isHidden = true
            previousKeyWindow?.makeKey()
            completion?()
        }
    }

    /// Recognises the tap triggers on the scene's windows without taking touches away from the app.
    func install(in scene: UIWindowScene) {
        for window in scene.windows where window !== self.window && installedRecognizers[ObjectIdentifier(window)] == nil {
            let recognizers: [AWLDebugTrigger: UITapGestureRecognizer] = [
                .threeFingerTap: makeRecognizer(action: #selector(handleThreeFingerTap), taps: 1, touches: Self.threeFingerTouches),
                .tripleTap: makeRecognizer(action: #selector(handleTripleTap), taps: 3, touches: 1),
            ]
            recognizers.values.forEach(window.addGestureRecognizer)
            installedRecognizers[ObjectIdentifier(window)] = recognizers
        }
        updateRecognizers()
    }

    /// The Simulator cannot send three touches; holding Option gives two.
    #if targetEnvironment(simulator)
    private static let threeFingerTouches = 2
    #else
    private static let threeFingerTouches = 3
    #endif

    private func makeRecognizer(action: Selector, taps: Int, touches: Int) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer(target: self, action: action)
        recognizer.numberOfTapsRequired = taps
        recognizer.numberOfTouchesRequired = touches
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = gestureDelegate
        return recognizer
    }

    private func updateRecognizers() {
        for recognizers in installedRecognizers.values {
            for (trigger, recognizer) in recognizers {
                recognizer.isEnabled = triggers.contains(trigger)
            }
        }
        if triggers.contains(.shake) {
            PanelShakeDetector.install()
        }
    }

    /// Light or dark for every app window, including UIKit screens and sheets; the panel keeps the system setting.
    func applyAppearance(_ scheme: DebugView.AppColorScheme) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for window in scenes.flatMap(\.windows) where window !== self.window {
            window.overrideUserInterfaceStyle = scheme.userInterfaceStyle
        }
    }

    func installInActiveScene() {
        if let scene = Self.activeScene() {
            install(in: scene)
        }
    }

    @objc private func handleThreeFingerTap() {
        trigger(.threeFingerTap)
    }

    @objc private func handleTripleTap() {
        trigger(.tripleTap)
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

private final class SimultaneousGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

/// The accessibility overrides apply to the app only, so the panel always shows the device's settings.
private struct DebugPanelRootView: View {
    @ObservedObject var content: DebugPanelPresenter.Content

    var body: some View {
        DebugView(fcmToken: content.fcmToken, customView: content.customView)
    }
}
