//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Foundation
import Testing
import UIKit

struct RecordingAttachmentTests {
    private static let video = Data([0, 0, 0, 0x18]) + Data("ftypmp42".utf8)
    private static let frames = Data([0xFF, 0xD8, 0xFF, 0xE0])
    private static let timeline = Data("# Recording timeline\n".utf8)
    private static let recording = RecordingAttachment(video: video, frames: frames, timeline: timeline)

    private static func request(recording: RecordingAttachment?) throws -> Data {
        let metadata = FeedbackMetadata(osVersion: "26.0", deviceModel: "iPhone17,1", appVersion: "1.0", buildNumber: "42",
                                        environment: "staging", locale: "de-CH", extraMetadata: [:], date: Date())
        let client = FeedbackClient(endpoint: URL(string: "https://feedback.example.com")!, appKey: "key-123")
        let request = try client.makeRequest(text: "t", metadata: metadata, screenshotJPEG: Data([0xFF]), recording: recording,
                                             idempotencyKey: UUID())
        return try #require(request.httpBody)
    }

    private static func part(_ name: String, _ filename: String, _ type: String, _ data: Data) -> Data {
        Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(type)\r\n\r\n".utf8)
            + data + Data("\r\n".utf8)
    }

    @Test
    func requestCarriesVideoFramesAndTimeline() throws {
        let body = try Self.request(recording: Self.recording)

        let video = try #require(body.range(of: Self.part("video", "recording.mp4", "video/mp4", Self.video)))
        let frames = try #require(body.range(of: Self.part("frames", "frames.jpg", "image/jpeg", Self.frames)))
        let timeline = try #require(body.range(of: Self.part("timeline", "timeline.md", "text/markdown; charset=utf-8", Self.timeline)))
        #expect(video.lowerBound < frames.lowerBound && frames.lowerBound < timeline.lowerBound)
    }

    @Test
    func framesAndTimelineNeverGoWithoutVideo() throws {
        let body = try Self.request(recording: RecordingAttachment(frames: Self.frames, timeline: Self.timeline))

        #expect(body.range(of: Data("name=\"frames\"".utf8)) == nil)
        #expect(body.range(of: Data("name=\"timeline\"".utf8)) == nil)
        #expect(body.range(of: Data("name=\"video\"".utf8)) == nil)
    }

    @Test
    func fittingDropsSheetAndTimelineFirstThenTheVideo() {
        let all = Self.video.count + Self.frames.count + Self.timeline.count

        #expect(Self.recording.fitting(maxBytes: all) == Self.recording)
        #expect(Self.recording.fitting(maxBytes: all - 1) == RecordingAttachment(video: Self.video))
        #expect(Self.recording.fitting(maxBytes: Self.video.count - 1) == RecordingAttachment(isTooLarge: true))
        #expect(RecordingAttachment(isTooLarge: true).fitting(maxBytes: 100) == RecordingAttachment(isTooLarge: true))
    }

    @MainActor
    @Test
    func switchIsOffByDefaultAndOnlyShowsWithARecording() {
        let config = FeedbackConfig(endpoint: URL(string: "https://feedback.example.com")!, appKey: "key-123", appVersion: "2.3.0",
                                    buildNumber: "1024", environment: "staging")
        // The test process does not contain AWLDebugTool, so the bridge is not found.
        #expect(RecordingAttachment.toolSource == nil)
        #expect(!FeedbackSession(screenshot: UIImage(), config: config).canAttachRecording)

        let session = FeedbackSession(screenshot: UIImage(), config: config, recordingSource: { Self.recording })
        #expect(session.canAttachRecording && !session.attachRecording)
    }
}
