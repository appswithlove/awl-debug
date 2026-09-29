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
    var events: [DebugToolViewModifier.ShowDebugToolEvents] = []

    private var window: UIWindow?
    private weak var previousKeyWindow: UIWindow?
    private var installedRecognizers: [ObjectIdentifier: UITapGestureRecognizer] = [:]
    private let gestureDelegate = SimultaneousGestureDelegate()

    var isOpen: Bool {
        window != nil
    }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(userDidTakeScreenshot),
                                               name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }

    @objc private func userDidTakeScreenshot() {
        trigger(.userDidTakeScreenshot)
    }

    func trigger(_ event: DebugToolViewModifier.ShowDebugToolEvents) {
        if events.contains(event) {
            open()
        }
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
        window.windowLevel = .alert + 1
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        root.present(host, animated: true)
    }

    func close() {
        guard let window = window else {
            return
        }
        self.window = nil
        let previousKeyWindow = previousKeyWindow
        window.rootViewController?.dismiss(animated: true) {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
    }

    /// Recognises three taps on the scene's windows without taking touches away from the app.
    func install(in scene: UIWindowScene) {
        for window in scene.windows where window !== self.window && installedRecognizers[ObjectIdentifier(window)] == nil {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap))
            recognizer.numberOfTapsRequired = 3
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = gestureDelegate
            window.addGestureRecognizer(recognizer)
            installedRecognizers[ObjectIdentifier(window)] = recognizer
        }
    }

    func installInActiveScene() {
        if let scene = Self.activeScene() {
            install(in: scene)
        }
    }

    @objc private func handleTripleTap() {
        trigger(.threeTaps)
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

/// The panel with the appearance settings the tool applies to the app.
private struct DebugPanelRootView: View {
    @ObservedObject var content: DebugPanelPresenter.Content

    @AppStorage(DebugView.Keys.preferredColorScheme)
    private var preferredColorScheme: DebugView.AppColorScheme = .auto

    @AppStorage(DebugView.Keys.preferredFontSize)
    private var preferredFontSize: DebugView.AppFontSize = .system

    var body: some View {
        DebugView(fcmToken: content.fcmToken, customView: content.customView)
            .applyFontSize(preferredFontSize.sizeCategory)
            .preferredColorScheme(preferredColorScheme.colorScheme)
    }
}
