import UIKit

/// `recording.mp4`, `frames.jpg` and `timeline.md` of a recording, for the ZIP export and for extensions.
enum RecordingExport {
    static let videoFileName = "recording.mp4"
    static let framesFileName = "frames.jpg"
    static let timelineFileName = "timeline.md"

    /// Encodes the newest `options.lastSeconds` of frames. Above `options.maxVideoBytes` once more at half resolution,
    /// then without any part; a longer timeline than `options.maxTimelineBytes` is left out. `nil` without a readable
    /// frame or when encoding fails.
    static func export(frames all: [RecordedFrame], events: [RecordingEvent], options: AWLDebugRecordingExportOptions,
                       timeZone: TimeZone = .current) async -> AWLDebugRecordingExport? {
        let frames = options.lastSeconds.map { Array(all.suffix(max($0, 0) * ScreenRecorder.framesPerSecond)) } ?? all
        guard let frameSize = frameSize(of: frames) else {
            return nil
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "awl-debug-export-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: videoFileName)

        var video: Data?
        for scale in [1, 0.5] as [CGFloat] {
            let size = ImagesToVideoExport.videoSize(for: frameSize, scale: scale)
            do {
                try await ImagesToVideoExport.createVideo(from: frames.map(\.url), size: size,
                                                          fps: ScreenRecorder.framesPerSecond, outputURL: url)
            } catch {
                return nil
            }
            let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? .max
            if bytes <= options.maxVideoBytes ?? .max {
                video = try? Data(contentsOf: url)
                break
            }
        }
        guard let video else {
            return AWLDebugRecordingExport(video: nil, frames: nil, timeline: nil, isVideoTooLarge: true)
        }
        let timeline = Data(RecordingTimeline.markdown(frames: frames, events: events, timeZone: timeZone).utf8)
        return AWLDebugRecordingExport(
            video: video,
            frames: contactSheet(frames: frames, timeZone: timeZone),
            timeline: timeline.count <= options.maxTimelineBytes ?? .max ? timeline : nil
        )
    }

    /// `awl-debug-recording-<yyyy-MM-dd_HH.mm.ss>.zip` in the temporary folder with all three files, for sharing.
    static func zip(frames: [RecordedFrame], events: [RecordingEvent], date: Date, timeZone: TimeZone = .current) async throws -> URL {
        guard let frameSize = frameSize(of: frames) else {
            throw ImagesToVideoExport.Failure()
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let name = "awl-debug-recording-\(formatter.string(from: date))"
        let temporary = FileManager.default.temporaryDirectory
        let folder = temporary.appending(path: name)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        try await ImagesToVideoExport.createVideo(from: frames.map(\.url), size: ImagesToVideoExport.videoSize(for: frameSize),
                                                  fps: ScreenRecorder.framesPerSecond,
                                                  outputURL: folder.appending(path: videoFileName))
        try contactSheet(frames: frames, timeZone: timeZone)?.write(to: folder.appending(path: framesFileName))
        try Data(RecordingTimeline.markdown(frames: frames, events: events, timeZone: timeZone).utf8)
            .write(to: folder.appending(path: timelineFileName))

        let zipURL = temporary.appending(path: "\(name).zip")
        try? FileManager.default.removeItem(at: zipURL)
        var coordinatorError: NSError?
        var copyError: Error?
        // Reading a folder "for uploading" hands out a ZIP of it; the system deletes it after the block.
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinatorError) { zipped in
            do {
                try FileManager.default.copyItem(at: zipped, to: zipURL)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError ?? copyError {
            throw error
        }
        return zipURL
    }

    // MARK: - Contact sheet

    static let sheetColumns = 4
    static let sheetTileWidth: CGFloat = 270
    static let sheetMaxTiles = 60
    static let sheetQuality: CGFloat = 0.7

    /// Frames spread evenly over the recording, the first and the last always included.
    static func sheetFrames(_ frames: [RecordedFrame]) -> [RecordedFrame] {
        guard frames.count > sheetMaxTiles else {
            return frames
        }
        let step = Double(frames.count - 1) / Double(sheetMaxTiles - 1)
        return (0 ..< sheetMaxTiles).map { frames[Int((Double($0) * step).rounded())] }
    }

    /// `frames.jpg`: 4 columns of 270 px wide tiles, each with its time (`HH:mm:ss.SSS`) at the bottom left.
    static func contactSheet(frames: [RecordedFrame], timeZone: TimeZone) -> Data? {
        guard let frameSize = frameSize(of: frames) else {
            return nil
        }
        let tiles = sheetFrames(frames)
        let tileSize = CGSize(width: sheetTileWidth, height: (sheetTileWidth * frameSize.height / frameSize.width).rounded())
        let rows = (tiles.count + sheetColumns - 1) / sheetColumns
        let sheetSize = CGSize(width: tileSize.width * CGFloat(sheetColumns), height: tileSize.height * CGFloat(rows))
        let formatter = RecordingTimeline.timeFormatter(timeZone: timeZone)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let sheet = UIGraphicsImageRenderer(size: sheetSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: sheetSize))
            for (index, frame) in tiles.enumerated() {
                let tile = CGRect(x: CGFloat(index % sheetColumns) * tileSize.width,
                                  y: CGFloat(index / sheetColumns) * tileSize.height,
                                  width: tileSize.width, height: tileSize.height)
                autoreleasepool {
                    if let image = UIImage(contentsOfFile: frame.url.path) {
                        image.draw(in: ImagesToVideoExport.aspectFit(image.size, in: tile.size).offsetBy(dx: tile.minX, dy: tile.minY))
                    }
                }
                let label = NSAttributedString(string: formatter.string(from: frame.date), attributes: attributes)
                let labelSize = label.size()
                let labelRect = CGRect(x: tile.minX, y: tile.maxY - labelSize.height - 6,
                                       width: labelSize.width + 8, height: labelSize.height + 6)
                UIColor.black.withAlphaComponent(0.6).setFill()
                context.fill(labelRect)
                label.draw(at: CGPoint(x: labelRect.minX + 4, y: labelRect.minY + 3))
            }
        }
        return sheet.jpegData(compressionQuality: sheetQuality)
    }

    /// Pixel size of the newest readable frame; the video and the tiles take its shape.
    private static func frameSize(of frames: [RecordedFrame]) -> CGSize? {
        for frame in frames.reversed() {
            if let image = UIImage(contentsOfFile: frame.url.path), let cgImage = image.cgImage {
                return CGSize(width: cgImage.width, height: cgImage.height)
            }
        }
        return nil
    }
}

/// `timeline.md`: one row per frame and per touch, keyboard or orientation event, and a `gap` row where nothing
/// was recorded for a while.
enum RecordingTimeline {
    /// Frames are normally a third of a second apart; a longer pause means nothing happened in between.
    static let gapThreshold: TimeInterval = 1
    /// Events up to this long before the first frame belong to it (the touch that started the recording).
    static let leadIn: Int64 = 1000

    static func touchEvent(phase: RecordingTouchPhase, at location: CGPoint, in screen: CGSize) -> String {
        func unit(_ value: CGFloat, _ length: CGFloat) -> String {
            String(format: "%.2f", length > 0 ? min(max(value / length, 0), 1) : 0)
        }
        let name = phase == .began ? "began" : phase == .ended ? "ended" : "moved"
        return "touch \(name) x=\(unit(location.x, screen.width)) y=\(unit(location.y, screen.height))"
    }

    static func markdown(frames: [RecordedFrame], events: [RecordingEvent], timeZone: TimeZone) -> String {
        guard let first = frames.first, let last = frames.last else {
            return ""
        }
        let time = timeFormatter(timeZone: timeZone)
        let start = DateFormatter()
        start.locale = Locale(identifier: "en_US_POSIX")
        start.calendar = Calendar(identifier: .gregorian)
        start.timeZone = timeZone
        start.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"

        // (time, order within the same time, frame number, event); a pause shows right after the frame before it.
        var rows: [(time: Int64, rank: Int, frame: Int, text: String)] = []
        for (index, frame) in frames.enumerated() {
            rows.append((frame.time, 0, index + 1, "frame"))
            if index + 1 < frames.count {
                let pause = TimeInterval(frames[index + 1].time - frame.time) / 1000
                if pause > gapThreshold {
                    rows.append((frame.time, 1, index + 1, "gap " + String(format: "%.1f", pause) + "s"))
                }
            }
        }
        var frameIndex = 0
        for event in events where event.time >= first.time - leadIn && event.time <= last.time + leadIn {
            while frameIndex + 1 < frames.count, frames[frameIndex + 1].time <= event.time {
                frameIndex += 1
            }
            rows.append((event.time, 2, frameIndex + 1, event.text.replacingOccurrences(of: "|", with: "/")))
        }
        let sorted = rows.enumerated().sorted {
            ($0.element.time, $0.element.rank, $0.offset) < ($1.element.time, $1.element.rank, $1.offset)
        }.map(\.element)

        var text = """
        # Recording timeline
        start: \(start.string(from: first.date)) · frames: \(frames.count) · fps: \(ScreenRecorder.framesPerSecond)

        | time | frame | event |
        |---|---|---|

        """
        for row in sorted {
            let date = Date(timeIntervalSince1970: TimeInterval(row.time) / 1000)
            text += "| \(time.string(from: date)) | \(row.frame) | \(row.text) |\n"
        }
        return text
    }

    static func timeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }
}
