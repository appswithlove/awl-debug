import Foundation

/// What `AWLDebugFeedback` reads from the tool. Feedback finds this class at runtime with
/// `NSClassFromString("AWLDebugToolBridge")`, so neither product links the other and only Foundation types cross.
@objc(AWLDebugToolBridge)
final class AWLDebugToolBridge: NSObject {
    /// `true` once `AWLDebugTool.start` ran.
    @objc static var isAvailable: Bool {
        AWLDebugTool.shared.networkLogger.didStart
    }

    /// Calls `completion` on the main thread with `logs.txt` from its `filters:` line on, as UTF-8
    /// and at most `LogsAttachment.bodyMaxBytes` long.
    @objc(feedbackLogsAttachment:)
    static func feedbackLogsAttachment(_ completion: @escaping (Data?) -> Void) {
        Task { @MainActor in
            let store = AWLDebugTool.shared.appLogs
            await store.readOSLog()
            completion(Data(LogsAttachment.current(logs: store, network: AWLDebugTool.shared.networkLogger).utf8))
        }
    }
}
