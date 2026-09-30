//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI
import UIKit

public extension View {
    /// Opens the feedback tool on the gestures in `FeedbackConfig.triggers`, from `AWLFeedback.start()` and from
    /// "Send feedback" in the `AWLDebugTool` panel. Attach once, at the root of the app. A `nil` config leaves
    /// the view untouched.
    func feedbackTool(config: FeedbackConfig?) -> some View {
        modifier(FeedbackToolModifier(config: config))
    }
}

private struct FeedbackToolModifier: ViewModifier {
    let config: FeedbackConfig?
    private let screenshotTaken = NotificationCenter.default
        .publisher(for: UIApplication.userDidTakeScreenshotNotification)

    func body(content: Content) -> some View {
        if let config {
            content
                .onAppear {
                    FeedbackQueueRunner.shared.start()
                    if config.triggers.contains(.shake) {
                        ShakeDetector.install()
                    }
                    FeedbackPresenter.shared.register(config)
                }
                .onDisappear {
                    FeedbackPresenter.shared.unregister()
                }
                .onReceive(screenshotTaken) { _ in
                    trigger(.screenshot, config: config)
                }
                .onReceive(NotificationCenter.default.publisher(for: ShakeDetector.notification)) { _ in
                    trigger(.shake, config: config)
                }
        } else {
            content
        }
    }

    private func trigger(_ trigger: FeedbackTrigger, config: FeedbackConfig) {
        guard config.triggers.contains(trigger) else {
            return
        }
        FeedbackPresenter.shared.present(config: config)
    }
}
