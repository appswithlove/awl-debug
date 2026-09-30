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

    /// Closes the panel so it is not in the feedback screenshot, then calls `completion` on the main thread.
    @objc(closePanel:)
    static func closePanel(_ completion: @escaping () -> Void) {
        Task { @MainActor in
            DebugPanelPresenter.shared.close(completion: completion)
        }
    }

    /// `true` when the current or the previous run's screen recording has frames.
    @objc static var hasRecording: Bool {
        let storage = RecordingStorage()
        return [storage.currentFolder, storage.lastFolder].contains { RecordingStorage.newestFrameDate(in: $0) != nil }
    }

    /// Calls `completion` on the main thread with `recording.mp4`, `frames.jpg` and `timeline.md` of the current
    /// recording, or of the previous run's without current frames. All `nil` without frames or when encoding fails;
    /// the flag is `true` when the video stayed too large for the service even at half resolution.
    @objc(feedbackRecording:)
    static func feedbackRecording(_ completion: @escaping (Data?, Data?, Data?, Bool) -> Void) {
        Task { @MainActor in
            guard let folder = ScreenRecorder.shared.feedbackRecordingFolder() else {
                completion(nil, nil, nil, false)
                return
            }
            let frames = RecordingStorage.timedFrames(in: folder)
            let events = RecordingStorage.events(in: folder)
            let parts = await Task.detached(priority: .userInitiated) {
                await RecordingExport.feedbackParts(frames: frames, events: events)
            }.value
            completion(parts.video, parts.frames, parts.timeline, parts.isTooLarge)
        }
    }
}
