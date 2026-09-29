@testable import AWLDebugTool
import Foundation
import Testing

/// Stands in for AWLDebugFeedback's `AWLFeedbackBridge`, which the tool reads by class name and selector.
@objc(AWLFeedbackBridgeFake)
final class AWLFeedbackBridgeFake: NSObject {
    @objc static var isAvailable = true
    @objc static var triggers: [String] = ["shake", "tripleTap"]
    @objc static var pendingCount = 0
    @objc static var starts = 0

    @objc static func start() {
        starts += 1
    }
}

@MainActor
@Suite(.serialized)
struct FeedbackEntryTests {
    init() {
        AWLFeedbackBridgeFake.isAvailable = true
        AWLFeedbackBridgeFake.pendingCount = 0
        AWLFeedbackBridgeFake.starts = 0
    }

    private func makeModel() -> FeedbackEntryModel {
        FeedbackEntryModel { FeedbackBridge.bridge(named: "AWLFeedbackBridgeFake") }
    }

    @Test func entryIsHiddenWithoutFeedback() {
        #expect(FeedbackBridge.current == nil)
        #expect(!FeedbackEntryModel().isAvailable)
    }

    @Test func entryIsHiddenWithoutConfig() {
        AWLFeedbackBridgeFake.isAvailable = false
        #expect(!makeModel().isAvailable)
    }

    @Test func entryShowsPendingAndStartsFeedback() {
        AWLFeedbackBridgeFake.pendingCount = 2
        let model = makeModel()
        #expect(model.isAvailable)
        #expect(model.pendingCount == 2)
        #expect(LS.Feedback.pending(model.pendingCount) == "2 pending")

        model.start()
        #expect(AWLFeedbackBridgeFake.starts == 1)
    }

    @Test func entryFollowsBridgeChanges() async {
        let model = makeModel()
        AWLFeedbackBridgeFake.isAvailable = false
        NotificationCenter.default.post(name: FeedbackBridge.didChangeNotification, object: nil)
        await Task.yield()
        for _ in 0 ..< 50 where model.isAvailable {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!model.isAvailable)
    }

    @Test func feedbackTriggersKeepOnlyKnownOnes() throws {
        let bridge = try #require(FeedbackBridge.bridge(named: "AWLFeedbackBridgeFake"))
        #expect(bridge.triggers == [.shake])
    }

    @Test func closePanelCallsBackWhenClosed() async throws {
        let bridge: AnyObject = try #require(NSClassFromString("AWLDebugToolBridge"))
        #expect(bridge.responds(to: NSSelectorFromString("closePanel:")))
        await withCheckedContinuation { continuation in
            AWLDebugToolBridge.closePanel { continuation.resume() }
        }
    }
}
