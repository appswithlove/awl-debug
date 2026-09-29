import AVFoundation
import XCTest
@testable import AWLDebugTool

final class RecordingExportTests: XCTestCase {
    private var folder: URL!
    private let utc = TimeZone(identifier: "UTC")!
    /// 2026-09-29T08:14:31.000Z
    private let start: Int64 = 1_790_669_671_000

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "recording-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Frames of a 402 × 874 screen, a third of a second apart, each a different colour with random detail.
    private func writeFrames(_ count: Int, size: CGSize = CGSize(width: 402, height: 874)) throws -> [RecordedFrame] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return try (0 ..< count).map { index in
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor(hue: CGFloat(index % 12) / 12, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor.black.setFill()
                context.fill(CGRect(x: 20, y: 40 + CGFloat(index * 4 % 700), width: 300, height: 30))
                // Detail like text, so the encoder needs its bit rate and a smaller video really is smaller.
                var generator = SystemRandomNumberGenerator()
                for _ in 0 ..< 600 {
                    UIColor(white: CGFloat.random(in: 0 ... 1, using: &generator), alpha: 1).setFill()
                    context.fill(CGRect(x: CGFloat.random(in: 0 ..< size.width, using: &generator),
                                        y: CGFloat.random(in: 0 ..< size.height, using: &generator), width: 6, height: 10))
                }
            }
            let time = start + Int64(index) * 333
            let url = folder.appending(path: "\(time).jpeg")
            try XCTUnwrap(image.jpegData(compressionQuality: 0.6)).write(to: url)
            return RecordedFrame(url: url, time: time)
        }
    }

    // AK-FB-9: H.264 MP4 at 3 fps from the last 60 s of frames, within the size limits.
    func testFeedbackVideoIsH264WithTheLastSixtySecondsOfFrames() async throws {
        let frames = try writeFrames(200)

        let parts = await RecordingExport.feedbackParts(frames: frames, events: [], timeZone: utc)

        let video = try XCTUnwrap(parts.video)
        XCTAssertEqual(String(decoding: video[4 ..< 8], as: UTF8.self), "ftyp")
        XCTAssertLessThanOrEqual(video.count, RecordingExport.maxVideoBytes)
        let (asset, track) = try await videoTrack(of: video)
        let descriptions = try await track.load(.formatDescriptions)
        let description = try XCTUnwrap(descriptions.first)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(description), kCMVideoCodecType_H264)
        let naturalSize = try await track.load(.naturalSize)
        XCTAssertEqual(naturalSize, CGSize(width: 402, height: 874))
        let frameRate = try await track.load(.nominalFrameRate)
        XCTAssertEqual(frameRate, 3, accuracy: 0.01)
        let count = try frameCount(of: track, in: asset)
        XCTAssertEqual(count, 180)

        let sheet = try XCTUnwrap(parts.frames)
        XCTAssertEqual(Array(sheet.prefix(3)), [0xFF, 0xD8, 0xFF])
        XCTAssertLessThanOrEqual(sheet.count, RecordingExport.maxFramesBytes)
        let sheetImage = try XCTUnwrap(UIImage(data: sheet)?.cgImage)
        XCTAssertEqual(sheetImage.width, 4 * 270)
        XCTAssertEqual(sheetImage.height, 15 * 587, "60 tiles, 270 × 587 each")

        let timeline = String(decoding: try XCTUnwrap(parts.timeline), as: UTF8.self)
        XCTAssertTrue(timeline.contains("start: 2026-09-29T08:14:37.660Z · frames: 180 · fps: 3"), timeline)
        XCTAssertFalse(parts.isTooLarge)
    }

    // Above the limit the video is encoded once more at half size, then left out together with sheet and timeline.
    func testTooLargeVideoIsHalvedThenLeftOut() async throws {
        let frames = try writeFrames(12)
        let full = await RecordingExport.feedbackParts(frames: frames, events: [])
        let fullSize = try XCTUnwrap(full.video).count

        let halved = await RecordingExport.feedbackParts(frames: frames, events: [], maxVideoBytes: fullSize - 1)
        let (_, track) = try await videoTrack(of: try XCTUnwrap(halved.video, "full \(fullSize)"))
        let halvedSize = try await track.load(.naturalSize)
        XCTAssertEqual(halvedSize, CGSize(width: 200, height: 436))
        XCTAssertNotNil(halved.frames)
        XCTAssertNotNil(halved.timeline)

        let none = await RecordingExport.feedbackParts(frames: frames, events: [], maxVideoBytes: 100)
        XCTAssertEqual(none.isTooLarge, true)
        XCTAssertNil(none.video)
        XCTAssertNil(none.frames)
        XCTAssertNil(none.timeline)
    }

    func testVideoSizeFitsLongEdgeAndIsEven() {
        XCTAssertEqual(ImagesToVideoExport.videoSize(for: CGSize(width: 1024, height: 1366)), CGSize(width: 958, height: 1280))
        XCTAssertEqual(ImagesToVideoExport.videoSize(for: CGSize(width: 393, height: 852)), CGSize(width: 392, height: 852))
        XCTAssertEqual(ImagesToVideoExport.videoSize(for: CGSize(width: 393, height: 852), scale: 0.5), CGSize(width: 196, height: 426))
    }

    func testSheetThinsOutEvenlyKeepingFirstAndLast() throws {
        let frames = (0 ..< 1800).map { RecordedFrame(url: folder.appending(path: "\($0).jpeg"), time: Int64($0)) }

        let tiles = RecordingExport.sheetFrames(frames)

        XCTAssertEqual(tiles.count, 60)
        XCTAssertEqual(tiles.first, frames.first)
        XCTAssertEqual(tiles.last, frames.last)
        XCTAssertEqual(Set(tiles.map(\.time)).count, 60)
    }

    func testTimelineListsFramesTouchesAndGaps() {
        let url = folder.appending(path: "x.jpeg")
        let frames = [
            RecordedFrame(url: url, time: start),
            RecordedFrame(url: url, time: start + 333),
            RecordedFrame(url: url, time: start + 12_733),
        ]
        let events = [
            RecordingEvent(time: start - 5000, text: "touch ended x=0.10 y=0.10"),
            RecordingEvent(time: start - 120, text: "touch began x=0.52 y=0.31"),
            RecordingEvent(time: start + 300, text: "touch ended x=0.52 y=0.31"),
            RecordingEvent(time: start + 12_800, text: "keyboard shown"),
        ]

        let markdown = RecordingTimeline.markdown(frames: frames, events: events, timeZone: utc)

        XCTAssertEqual(markdown, """
        # Recording timeline
        start: 2026-09-29T08:14:31.000Z · frames: 3 · fps: 3

        | time | frame | event |
        |---|---|---|
        | 08:14:30.880 | 1 | touch began x=0.52 y=0.31 |
        | 08:14:31.000 | 1 | frame |
        | 08:14:31.300 | 1 | touch ended x=0.52 y=0.31 |
        | 08:14:31.333 | 2 | frame |
        | 08:14:43.733 | 3 | gap 12.4s |
        | 08:14:43.733 | 3 | frame |
        | 08:14:43.800 | 3 | keyboard shown |

        """)
    }

    func testTouchEventIsInUnitCoordinates() {
        let screen = CGSize(width: 400, height: 800)
        XCTAssertEqual(RecordingTimeline.touchEvent(phase: .began, at: CGPoint(x: 208, y: 248), in: screen), "touch began x=0.52 y=0.31")
        XCTAssertEqual(RecordingTimeline.touchEvent(phase: .ended, at: CGPoint(x: 500, y: -3), in: screen), "touch ended x=1.00 y=0.00")
    }

    // AK-REC-6: the export ZIP holds recording.mp4, frames.jpg and timeline.md.
    func testZipHoldsVideoSheetAndTimeline() async throws {
        let frames = try writeFrames(6)
        let date = Date(timeIntervalSince1970: TimeInterval(start) / 1000)

        let zip = try await RecordingExport.zip(frames: frames, events: [RecordingEvent(time: start, text: "keyboard shown")],
                                                date: date, timeZone: utc)
        defer { try? FileManager.default.removeItem(at: zip) }

        XCTAssertEqual(zip.lastPathComponent, "awl-debug-recording-2026-09-29_08.14.31.zip")
        let data = try Data(contentsOf: zip)
        XCTAssertEqual(Array(data.prefix(2)), Array("PK".utf8))
        for name in ["recording.mp4", "frames.jpg", "timeline.md"] {
            XCTAssertNotNil(data.range(of: Data(name.utf8)), name)
        }
    }

    func testStorageKeepsEventsWithTheRecording() throws {
        let storage = RecordingStorage(root: folder)
        let jpeg = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.jpegData(compressionQuality: 0.6))
        let date = Date(timeIntervalSince1970: TimeInterval(start) / 1000)
        storage.write(jpeg, capturedAt: date, maxFrames: 2)
        storage.appendEvent("touch began x=0.50 y=0.50", at: date)
        storage.appendEvent("keyboard shown", at: date.addingTimeInterval(1))
        for second in 1 ... 6 {
            storage.write(jpeg, capturedAt: date.addingTimeInterval(TimeInterval(second)), maxFrames: 2)
        }
        storage.appendEvent("keyboard hidden", at: date.addingTimeInterval(7))

        XCTAssertEqual(RecordingStorage.events(in: storage.currentFolder).map(\.text),
                       ["touch began x=0.50 y=0.50", "keyboard shown", "keyboard hidden"])

        // Once there are more events than twice the frames, the newest ones not older than the oldest frame stay.
        storage.appendEvent("keyboard shown", at: date.addingTimeInterval(8))
        storage.appendEvent("orientation landscape", at: date.addingTimeInterval(8.5))
        storage.write(jpeg, capturedAt: date.addingTimeInterval(9), maxFrames: 2)
        let kept = ["keyboard shown", "orientation landscape"]
        XCTAssertEqual(RecordingStorage.events(in: storage.currentFolder).map(\.text), kept)

        RecordingStorage(root: folder).rotate()
        XCTAssertEqual(RecordingStorage.events(in: storage.lastFolder).map(\.text), kept)
        XCTAssertEqual(RecordingStorage.timedFrames(in: storage.lastFolder).count, 2)
    }

    private func videoTrack(of data: Data) async throws -> (AVAsset, AVAssetTrack) {
        let url = folder.appending(path: "\(UUID().uuidString).mp4")
        try data.write(to: url)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        return (asset, try XCTUnwrap(tracks.first))
    }

    private func frameCount(of track: AVAssetTrack, in asset: AVAsset) throws -> Int {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        reader.startReading()
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            if CMSampleBufferGetNumSamples(sample) > 0 {
                count += 1
            }
        }
        return count
    }
}
