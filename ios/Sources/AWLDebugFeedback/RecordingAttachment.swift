//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// The screen recording as parts `video`, `frames` and `timeline`, encoded by `AWLDebugTool` through its bridge.
struct RecordingAttachment: Equatable {
    var video: Data?
    var frames: Data?
    var timeline: Data?
    /// The video was too large for the service, so it is left out.
    var isTooLarge = false

    typealias Source = @MainActor () async -> RecordingAttachment

    /// `nil` without `AWLDebugTool` in the app, before `AWLDebugTool.start` or without a recording.
    static var toolSource: Source? {
        guard let bridge = NSClassFromString("AWLDebugToolBridge"),
              let isAvailable = LogsAttachment.classMethod(of: bridge, "isAvailable", as: Flag.self),
              isAvailable(bridge, NSSelectorFromString("isAvailable")),
              let hasRecording = LogsAttachment.classMethod(of: bridge, "hasRecording", as: Flag.self),
              hasRecording(bridge, NSSelectorFromString("hasRecording")),
              let recording = LogsAttachment.classMethod(of: bridge, "feedbackRecording:", as: FeedbackRecording.self) else {
            return nil
        }
        return {
            await withCheckedContinuation { continuation in
                recording(bridge, NSSelectorFromString("feedbackRecording:")) { video, frames, timeline, isTooLarge in
                    continuation.resume(returning: RecordingAttachment(video: video, frames: frames, timeline: timeline,
                                                                       isTooLarge: isTooLarge))
                }
            }
        }
    }

    /// Leaves out the contact sheet and the timeline, then the video, until the parts fit into `maxBytes`.
    /// `frames` and `timeline` never go without `video`.
    func fitting(maxBytes: Int) -> RecordingAttachment {
        guard let video else {
            return RecordingAttachment(isTooLarge: isTooLarge)
        }
        if video.count + (frames?.count ?? 0) + (timeline?.count ?? 0) <= maxBytes {
            return self
        }
        if video.count <= maxBytes {
            return RecordingAttachment(video: video)
        }
        return RecordingAttachment(isTooLarge: true)
    }

    private typealias Flag = @convention(c) (AnyClass, Selector) -> Bool
    private typealias FeedbackRecording = @convention(c) (
        AnyClass, Selector, @escaping @convention(block) (Data?, Data?, Data?, Bool) -> Void
    ) -> Void
}
