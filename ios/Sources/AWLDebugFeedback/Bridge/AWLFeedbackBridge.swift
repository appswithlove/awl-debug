//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// What `AWLDebugTool` reads from feedback for its "Send feedback" entry and its triggers. The tool finds this
/// class at runtime with `NSClassFromString("AWLFeedbackBridge")`, so neither product links the other and only
/// Foundation types cross. Call on the main thread.
@objc(AWLFeedbackBridge)
@MainActor
final class AWLFeedbackBridge: NSObject {
    /// Posted when `isAvailable`, `triggers` or `pendingCount` change.
    static let didChangeNotification = Notification.Name("AWLFeedbackBridgeDidChange")

    /// `true` while a configured `feedbackTool` is on screen.
    @objc static var isAvailable: Bool {
        FeedbackPresenter.shared.config != nil
    }

    /// Raw values of `FeedbackConfig.triggers`, e.g. `["screenshot", "shake"]`.
    @objc static var triggers: [String] {
        FeedbackPresenter.shared.config?.triggers.map(\.rawValue).sorted() ?? []
    }

    /// Reports waiting in the offline queue.
    @objc static var pendingCount: Int {
        FeedbackQueueRunner.shared.pendingCount
    }

    /// Same as `AWLFeedback.start()`.
    @objc static func start() {
        AWLFeedback.start()
    }
}
