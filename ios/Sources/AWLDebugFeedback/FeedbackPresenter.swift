//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Combine
import SwiftUI
import UIKit

/// Shows the feedback UI in a window of its own above everything the app presents, so it opens
/// the same way over sheets, full-screen covers and alerts, and never disturbs their state.
@MainActor
final class FeedbackPresenter {
    static let shared = FeedbackPresenter()

    /// The config of the `feedbackTool` on screen; used by `AWLFeedback.start()` and the panel entry.
    private(set) var config: FeedbackConfig?
    private var window: UIWindow?
    private var isClosingPanel = false
    private var pendingCountObserver: AnyCancellable?
    private let sentConfirmation = SentConfirmationPresenter()

    func register(_ config: FeedbackConfig) {
        self.config = config
        pendingCountObserver = pendingCountObserver ?? FeedbackQueueRunner.shared.$pendingCount
            .removeDuplicates()
            .sink { _ in
                // `@Published` emits before the value is stored.
                Task { @MainActor in Self.announceChange() }
            }
        Self.announceChange()
    }

    func unregister() {
        config = nil
        Self.announceChange()
    }

    func start() {
        guard let config else {
            return
        }
        present(config: config)
    }

    /// Closes the debug panel first, so it is not in the screenshot.
    func present(config: FeedbackConfig) {
        guard window == nil, !isClosingPanel else {
            return
        }
        isClosingPanel = true
        ToolBridge.closePanel { [weak self] in
            self?.isClosingPanel = false
            self?.show(config: config)
        }
    }

    private func show(config: FeedbackConfig) {
        guard window == nil, let scene = Self.activeScene() else {
            return
        }
        guard let screenshot = ScreenshotRenderer.capture(scene: scene) else {
            return
        }
        let previousKeyWindow = scene.keyWindow
        let session = FeedbackSession(screenshot: screenshot, config: config)

        let host = UIHostingController(rootView: FeedbackView(session: session) { [weak self] outcome in
            self?.dismiss(restoring: previousKeyWindow, outcome: outcome, notice: session.recordingNotice)
        })
        host.modalPresentationStyle = .fullScreen

        let root = UIViewController()
        root.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.accessibilityIdentifier = "AWLDebugWindow" // Not in screen recordings.
        window.windowLevel = .alert + 1
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        root.present(host, animated: true)
    }

    private func dismiss(restoring previousKeyWindow: UIWindow?, outcome: FeedbackOutcome, notice: String?) {
        guard let window else {
            return
        }
        window.rootViewController?.dismiss(animated: true) { [weak self] in
            window.isHidden = true
            previousKeyWindow?.makeKey()
            self?.window = nil
            guard let scene = window.windowScene else {
                return
            }
            switch outcome {
            case .sent:
                self?.sentConfirmation.show(in: scene, message: ["Feedback sent", notice].compactMap { $0 }.joined(separator: "\n"),
                                            systemImage: "checkmark.circle.fill")
            case .queued:
                self?.sentConfirmation.show(
                    in: scene,
                    message: ["Saved. It will be sent when you are online.", notice].compactMap { $0 }.joined(separator: "\n"),
                    systemImage: "tray.and.arrow.up.fill"
                )
            case .cancelled:
                break
            }
        }
    }

    private static func announceChange() {
        NotificationCenter.default.post(name: AWLFeedbackBridge.didChangeNotification, object: nil)
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
