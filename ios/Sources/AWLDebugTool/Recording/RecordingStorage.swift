import Foundation

/// Frames on disk: `Library/Caches/AWLDebug/recording/current/` while recording, moved to `last/` on the next start,
/// so a recording survives a crash. File names are capture times in milliseconds (`<ms>.jpeg`).
/// Not thread-safe; the recorder uses it from its encoding queue only.
final class RecordingStorage: @unchecked Sendable {
    private let root: URL
    private let fileManager = FileManager.default
    private var currentFrames: [Int64] = []

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
