//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

public enum AWLFeedback {
    /// Starts a report from code, e.g. from a button of the app. Closes the debug panel first, so the screenshot
    /// shows the app only. Does nothing without a configured `feedbackTool` on screen or while a report is open.
    @MainActor
    public static func start() {
        FeedbackPresenter.shared.start()
    }
}
