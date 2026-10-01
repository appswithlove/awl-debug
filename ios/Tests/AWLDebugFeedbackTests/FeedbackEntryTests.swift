//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Foundation
import Testing

/// What `AWLDebugTool` reads through the Objective-C runtime for its "Send feedback" entry and its triggers.
@MainActor
@Suite(.serialized)
struct FeedbackEntryTests {
    private func makeConfig(triggers: Set<FeedbackTrigger> = [.shake, .screenshot]) throws -> FeedbackConfig {
        try FeedbackConfig(endpoint: #require(URL(string: "https://feedback.example.com")), appKey: "key-123",
                           appVersion: "1.0", buildNumber: "42", environment: "staging", triggers: triggers)
    }

    /// Reads the bridge the way the tool does: by class name and selector.
    private func bridgeValue(_ key: String) throws -> Any? {
        let bridge: AnyObject = try #require(NSClassFromString("AWLFeedbackBridge"))
        return bridge.value(forKey: key)
    }

    @Test func bridgeReportsTheRegisteredConfig() throws {
        var changes = 0
        let observer = NotificationCenter.default.addObserver(forName: Notification.Name("AWLFeedbackBridgeDidChange"),
                                                              object: nil, queue: nil) { _ in changes += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        FeedbackPresenter.shared.register(try makeConfig(triggers: [.shake]))
        #expect(try bridgeValue("isAvailable") as? Bool == true)
        #expect(try bridgeValue("triggers") as? [String] == ["shake"])
        #expect(try bridgeValue("pendingCount") as? Int == 0)

        FeedbackPresenter.shared.unregister()
        #expect(try bridgeValue("isAvailable") as? Bool == false)
        #expect(try bridgeValue("triggers") as? [String] == [])
        #expect(changes == 2)
    }

    @Test func defaultTriggersAreShakeAndScreenshot() throws {
        #expect(try makeConfig().triggers == [.shake, .screenshot])
    }

    @available(*, deprecated)
    @Test func shakeToReportMapsToTriggers() throws {
        let url = try #require(URL(string: "https://feedback.example.com"))
        let off = FeedbackConfig(endpoint: url, appKey: "k", appVersion: "1", buildNumber: "1", environment: "e", shakeToReport: false)
        let on = FeedbackConfig(endpoint: url, appKey: "k", appVersion: "1", buildNumber: "1", environment: "e", shakeToReport: true)
        #expect(off.triggers == [.screenshot])
        #expect(!off.shakeToReport)
        #expect(on.triggers == [.shake, .screenshot])
        #expect(on.shakeToReport)
    }

    @Test func startWithoutConfigDoesNothing() {
        FeedbackPresenter.shared.unregister()
        AWLFeedback.start()
        #expect(FeedbackPresenter.shared.config == nil)
    }
}
