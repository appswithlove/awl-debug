//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import SwiftUI
import UIKit

public extension View {
    /// Opens the feedback tool when the user takes a system screenshot or, unless
    /// `shakeToReport` is off, shakes the device.
    /// Attach once, at the root of the app. A `nil` config leaves the view untouched.
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
                    if config.shakeToReport {
                        ShakeDetector.install()
                    }
                }
                .onReceive(screenshotTaken) { _ in
                    FeedbackPresenter.shared.present(config: config)
                }
                .onReceive(NotificationCenter.default.publisher(for: ShakeDetector.notification)) { _ in
                    guard config.shakeToReport else {
                        return
                    }
                    FeedbackPresenter.shared.present(config: config)
                }
        } else {
            content
        }
    }
}
