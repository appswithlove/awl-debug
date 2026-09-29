//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI
import UIKit

/// Shows the feedback UI in a window of its own above everything the app presents, so it opens
/// the same way over sheets, full-screen covers and alerts, and never disturbs their state.
@MainActor
final class FeedbackPresenter {
    static let shared = FeedbackPresenter()

    private var window: UIWindow?
    private let sentConfirmation = SentConfirmationPresenter()

    func present(config: FeedbackConfig) {
        guard window == nil, let scene = Self.activeScene() else {
            return
        }
        guard let screenshot = ScreenshotRenderer.capture(scene: scene) else {
            return
        }
        let previousKeyWindow = scene.keyWindow
        let session = FeedbackSession(screenshot: screenshot, config: config)

        let host = UIHostingController(rootView: FeedbackView(session: session) { [weak self] outcome in
            self?.dismiss(restoring: previousKeyWindow, outcome: outcome)
        })
        host.modalPresentationStyle = .fullScreen

        let root = UIViewController()
        root.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
        root.present(host, animated: true)
    }

    private func dismiss(restoring previousKeyWindow: UIWindow?, outcome: FeedbackOutcome) {
        guard let window else {
            return
        }
        window.rootViewController?.dismiss(animated: true) { [weak self] in
            window.isHidden = true
            previousKeyWindow?.makeKey()
            self?.window = nil
            if outcome == .sent, let scene = window.windowScene {
                self?.sentConfirmation.show(in: scene)
            }
        }
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
