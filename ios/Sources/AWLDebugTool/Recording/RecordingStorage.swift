import Foundation

/// Frames on disk: `Library/Caches/AWLDebug/recording/current/` while recording, moved to `last/` on the next start,
/// so a recording survives a crash. File names are capture times in milliseconds (`<ms>.jpeg`); touches, keyboard and
/// orientation changes go to `events.tsv` (`<ms>\t<event>` per line) for the export's timeline.
/// Not thread-safe; the recorder uses it from its encoding queue only.
final class RecordingStorage: @unchecked Sendable {
    private let root: URL
    private let fileManager = FileManager.default
    private var currentFrames: [Int64] = []
    private var currentEvents: [RecordingEvent]?
    static let eventsFileName = "events.tsv"

    var currentFolder: URL { root.appending(path: "current") }
    var lastFolder: URL { root.appending(path: "last") }

    init(root: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "AWLDebug/recording")) {
        self.root = root
    }

    /// Replaces `last` with the previous run's `current`. Call once per process, before the first frame.
    func rotate() {
        try? fileManager.removeItem(at: lastFolder)
        if fileManager.fileExists(atPath: currentFolder.path) {
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try? fileManager.moveItem(at: currentFolder, to: lastFolder)
        }
        currentFrames = []
        currentEvents = nil
    }

    /// Writes one frame and drops the oldest ones beyond `maxFrames`.
    func write(_ jpeg: Data, capturedAt date: Date, maxFrames: Int) {
        try? fileManager.createDirectory(at: currentFolder, withIntermediateDirectories: true)
        if currentFrames.isEmpty {
            currentFrames = Self.frameTimes(in: currentFolder)
        }
        var time = Int64((date.timeIntervalSince1970 * 1000).rounded())
        if let newest = currentFrames.last, time <= newest {
            time = newest + 1
        }
        guard (try? jpeg.write(to: Self.url(of: time, in: currentFolder), options: .atomic)) != nil else {
            return
        }
        currentFrames.append(time)
        while currentFrames.count > max(1, maxFrames) {
            try? fileManager.removeItem(at: Self.url(of: currentFrames.removeFirst(), in: currentFolder))
        }
        dropOldEvents(maxFrames: maxFrames)
    }

    /// Appends one timeline event, e.g. `touch began x=0.52 y=0.31`.
    func appendEvent(_ text: String, at date: Date) {
        try? fileManager.createDirectory(at: currentFolder, withIntermediateDirectories: true)
        let event = RecordingEvent(time: Int64((date.timeIntervalSince1970 * 1000).rounded()), text: text)
        var events = currentEvents ?? Self.events(in: currentFolder)
        events.append(event)
        currentEvents = events
        let url = currentFolder.appending(path: Self.eventsFileName)
        let line = Data(event.line.utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url, options: .atomic)
        }
    }

    /// Once there are twice as many events as frames allowed, rewrites `events.tsv` with the newest events
    /// that are not older than the oldest frame, at most `maxFrames` of them.
    private func dropOldEvents(maxFrames: Int) {
        guard let events = currentEvents, events.count > 2 * max(1, maxFrames), let oldest = currentFrames.first else {
            return
        }
        let kept = Array(events.filter { $0.time >= oldest }.suffix(max(1, maxFrames)))
        currentEvents = kept
        try? Data(kept.map(\.line).joined().utf8).write(to: currentFolder.appending(path: Self.eventsFileName), options: .atomic)
    }

    /// Timeline events of `folder`, oldest first.
    static func events(in folder: URL) -> [RecordingEvent] {
        guard let text = try? String(contentsOf: folder.appending(path: eventsFileName), encoding: .utf8) else {
            return []
        }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let time = Int64(parts[0]) else {
                return nil
            }
            return RecordingEvent(time: time, text: String(parts[1]))
        }.sorted { $0.time < $1.time }
    }

    /// Frames of `folder` with their capture times, oldest first.
    static func timedFrames(in folder: URL) -> [RecordedFrame] {
        frameTimes(in: folder).map { RecordedFrame(url: url(of: $0, in: folder), time: $0) }
    }

    /// Frames of `folder`, oldest first.
    static func frames(in folder: URL) -> [URL] {
        frameTimes(in: folder).map { url(of: $0, in: folder) }
    }

    /// When the newest frame of `folder` was taken, `nil` without frames.
    static func newestFrameDate(in folder: URL) -> Date? {
        frameTimes(in: folder).last.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }

    private static func frameTimes(in folder: URL) -> [Int64] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.compactMap { name in
            name.hasSuffix(".jpeg") ? Int64(name.dropLast(5)) : nil
        }.sorted()
    }

    private static func url(of time: Int64, in folder: URL) -> URL {
        folder.appending(path: "\(time).jpeg")
    }
}

/// One stored frame; `time` is the capture time in milliseconds since 1970.
struct RecordedFrame: Equatable {
    let url: URL
    let time: Int64

    var date: Date { Date(timeIntervalSince1970: TimeInterval(time) / 1000) }
}

/// Something that happened during the recording, shown in the export's timeline.
struct RecordingEvent: Equatable {
    let time: Int64
    let text: String

    var date: Date { Date(timeIntervalSince1970: TimeInterval(time) / 1000) }

    fileprivate var line: String {
        "\(time)\t\(text.replacingOccurrences(of: "\n", with: " "))\n"
    }
}
