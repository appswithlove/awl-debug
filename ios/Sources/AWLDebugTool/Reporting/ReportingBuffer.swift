import Foundation

/// File buffer for remote reporting, one folder per session:
///
/// ```
/// <root>/sessions/<sessionId>/session.json    session object and bookkeeping
/// <root>/sessions/<sessionId>/entries.txt     one entry per line, not yet in a batch
/// <root>/batches/<seq>_<sessionId>_<n>.json.gz  sealed batches, oldest first, fixed bytes
/// ```
///
/// Everything together stays below `maxBytes`; the oldest entries are dropped first and counted in
/// `droppedCount`. Not thread-safe: the caller runs all calls on one queue.
final class ReportingBuffer {
    enum EntryKind: Character {
        case network = "n"
        case metric = "m"
    }

    static let defaultMaxBytes = 10 * 1024 * 1024
    static let maxEntries = 2000
    static let maxBatchGzipBytes = 1024 * 1024
    static let batchSuffix = ".json.gz"
    private static let maxRawChunkBytes = 8 * 1024 * 1024
    private static let sessionFile = "session.json"
    private static let entriesFile = "entries.txt"

    private struct Record: Codable {
        var session: ReportingSession
        /// `endedAt` of the last sealed batch, to seal a batch when only `endedAt` changed.
        var sealedEndedAtMillis: Int64?
        var lastEntryMillis: Int64?
        var droppedCount = 0
    }

    private struct Entry {
        let kind: EntryKind
        let timestampMillis: Int64
        let json: String
    }

    private let root: URL
    private let maxBytes: Int
    private let now: () -> Int64
    private let fileManager = FileManager.default
    private var records: [String: Record] = [:]
    private var totalBytes = 0
    private var nextSeq = 0

    private var sessionsDir: URL { root.appendingPathComponent("sessions", isDirectory: true) }
    private var batchesDir: URL { root.appendingPathComponent("batches", isDirectory: true) }

    init(root: URL, maxBytes: Int = defaultMaxBytes, now: @escaping () -> Int64 = { ReportingJSON.millis(Date()) }) {
        self.root = root
        self.maxBytes = maxBytes
        self.now = now
    }

    var sizeBytes: Int { totalBytes }

    /// Sessions left over from an earlier process, oldest first.
    func load() -> [ReportingSession] {
        records = [:]
        for dir in contents(of: sessionsDir) {
            if let record = readRecord(in: dir) {
                records[record.session.id] = record
            } else {
                try? fileManager.removeItem(at: dir)
            }
        }
        nextSeq = (sealedBatches().compactMap { Int($0.lastPathComponent.prefix { $0 != "_" }) }.max() ?? -1) + 1
        totalBytes = size(of: root)
        return records.values.map(\.session).sorted { $0.startedAtMillis < $1.startedAtMillis }
    }

    func droppedCount(sessionId: String) -> Int {
        records[sessionId]?.droppedCount ?? 0
    }

    func put(session: ReportingSession) {
        var record = records[session.id] ?? Record(session: session)
        record.session = session
        write(record)
    }

    func append(sessionId: String, timestampMillis: Int64, kind: EntryKind, json: String) {
        guard var record = records[sessionId] else { return }
        let line = Data("\(kind.rawValue)\(timestampMillis)\t\(json)\n".utf8)
        let file = entriesURL(sessionId)
        // Throwing calls only: the old `write(_:)` raises an Objective-C exception when the disk is full.
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            guard (try? handle.seekToEnd()) != nil, (try? handle.write(contentsOf: line)) != nil else { return }
        } else {
            guard (try? line.write(to: file)) != nil else { return }
        }
        totalBytes += line.count
        record.lastEntryMillis = max(record.lastEntryMillis ?? timestampMillis, timestampMillis)
        records[sessionId] = record
        if totalBytes > maxBytes {
            trim()
        }
    }

    /// Moves the pending entries of `sessionId` into sealed batches. With `finish` the session is
    /// done: a missing `endedAt` becomes the time of its last entry and its folder is removed.
    @discardableResult
    func seal(sessionId: String, finish: Bool = false) -> [URL] {
        guard var record = records[sessionId] else { return [] }
        let entries = readEntries(sessionId)
        var endedAt = record.session.endedAtMillis
        if endedAt == nil, finish {
            endedAt = entries.last?.timestampMillis ?? record.lastEntryMillis ?? record.session.startedAtMillis
        }
        var session = record.session
        session.endedAtMillis = endedAt
        let needsBatch = !entries.isEmpty || record.droppedCount > 0 || (endedAt != nil && endedAt != record.sealedEndedAtMillis)
        let written = needsBatch ? writeBatches(session: session, entries: entries, droppedCount: record.droppedCount) : []
        // Entries a batch could not hold were added to the count while writing.
        record.droppedCount = (records[sessionId]?.droppedCount ?? record.droppedCount) - record.droppedCount
        record.sealedEndedAtMillis = endedAt
        if let last = entries.last {
            record.lastEntryMillis = max(record.lastEntryMillis ?? 0, last.timestampMillis)
        }
        let entriesFile = entriesURL(sessionId)
        totalBytes -= fileSize(entriesFile)
        try? fileManager.removeItem(at: entriesFile)
        if finish {
            let dir = sessionDir(sessionId)
            totalBytes -= size(of: dir)
            try? fileManager.removeItem(at: dir)
            records[sessionId] = nil
        } else {
            write(record)
        }
        if totalBytes > maxBytes {
            trim()
        }
        return written
    }

    /// Sealed batches, oldest first. Each file is a gzip-compressed batch ready to send.
    func sealedBatches() -> [URL] {
        contents(of: batchesDir)
            .filter { $0.lastPathComponent.hasSuffix(Self.batchSuffix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Removes a batch once the service has accepted or rejected it for good.
    @discardableResult
    func deleteBatch(_ batch: URL) -> Bool {
        let size = fileSize(batch)
        guard (try? fileManager.removeItem(at: batch)) != nil else { return false }
        totalBytes -= size
        return true
    }

    // MARK: - Batches

    private func writeBatches(session: ReportingSession, entries: [Entry], droppedCount: Int) -> [URL] {
        var chunks: [[Entry]] = []
        var chunk: [Entry] = []
        var logs = 0
        var metrics = 0
        var rawBytes = 0
        for entry in entries {
            let isFull = entry.kind == .network ? logs >= Self.maxEntries : metrics >= Self.maxEntries
            if isFull || rawBytes + entry.json.utf8.count > Self.maxRawChunkBytes {
                chunks.append(chunk)
                chunk = []
                logs = 0
                metrics = 0
                rawBytes = 0
            }
            chunk.append(entry)
            if entry.kind == .network {
                logs += 1
            } else {
                metrics += 1
            }
            rawBytes += entry.json.utf8.count
        }
        chunks.append(chunk)
        var dropped = droppedCount
        return chunks.filter { !$0.isEmpty || chunks.count == 1 }.flatMap { chunk -> [URL] in
            defer { dropped = 0 }
            return writeBatch(session: session, entries: chunk[...], droppedCount: dropped)
        }
    }

    /// Writes one batch, split in halves while it is larger than `maxBatchGzipBytes`.
    private func writeBatch(session: ReportingSession, entries: ArraySlice<Entry>, droppedCount: Int) -> [URL] {
        let batchId = UUID().uuidString.lowercased()
        guard let gzipped = Gzip.compress(Data(batchJSON(batchId: batchId, session: session, entries: entries, droppedCount: droppedCount).utf8)) else {
            return []
        }
        if gzipped.count > Self.maxBatchGzipBytes && entries.count > 1 {
            let half = entries.startIndex + entries.count / 2
            return writeBatch(session: session, entries: entries[..<half], droppedCount: droppedCount)
                + writeBatch(session: session, entries: entries[half...], droppedCount: 0)
        }
        if gzipped.count > Self.maxBatchGzipBytes {
            // A single entry cannot get this large with the body cap; drop it rather than block the queue.
            records[session.id]?.droppedCount += entries.count
            return []
        }
        try? fileManager.createDirectory(at: batchesDir, withIntermediateDirectories: true)
        // The count covers what the batch carries in `droppedCount`, too, so trimming it keeps the total.
        let name = String(format: "%016d_%@_%d%@", nextSeq, session.id, entries.count + droppedCount, Self.batchSuffix)
        nextSeq += 1
        let file = batchesDir.appendingPathComponent(name)
        guard (try? gzipped.write(to: file, options: .atomic)) != nil else { return [] }
        totalBytes += gzipped.count
        return [file]
    }

    private func batchJSON(batchId: String, session: ReportingSession, entries: ArraySlice<Entry>, droppedCount: Int) -> String {
        var json = "{\"batchId\":\"\(batchId)\",\"sentAt\":\"\(ReportingJSON.timestamp(now()))\""
        json += ",\"session\":" + (ReportingJSON.encode(ReportingJSON.session(session)) ?? "{}")
        json += array(named: "networkLogs", entries.filter { $0.kind == .network })
        json += array(named: "metrics", entries.filter { $0.kind == .metric })
        if droppedCount > 0 {
            json += ",\"droppedCount\":\(droppedCount)"
        }
        return json + "}"
    }

    private func array(named name: String, _ entries: [Entry]) -> String {
        guard !entries.isEmpty else { return "" }
        return ",\"\(name)\":[" + entries.map(\.json).joined(separator: ",") + "]"
    }

    // MARK: - Overflow

    /// Drops the oldest data until the buffer is back below 90 % of `maxBytes`.
    private func trim() {
        let target = maxBytes * 9 / 10
        while totalBytes > target {
            if let oldestBatch = sealedBatches().first {
                let parts = oldestBatch.lastPathComponent.dropLast(Self.batchSuffix.count).split(separator: "_")
                let count = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
                let owner = parts.count > 1 && records[String(parts[1])] != nil
                    ? String(parts[1])
                    : records.values.max { $0.session.startedAtMillis < $1.session.startedAtMillis }?.session.id
                if let owner, var record = records[owner] {
                    record.droppedCount += count
                    write(record)
                }
                guard deleteBatch(oldestBatch) else { return }
                continue
            }
            guard var record = records.values
                .sorted(by: { $0.session.startedAtMillis < $1.session.startedAtMillis })
                .first(where: { fileSize(entriesURL($0.session.id)) > 0 }) else {
                return
            }
            let file = entriesURL(record.session.id)
            let lines = (try? String(contentsOf: file, encoding: .utf8))?.split(separator: "\n") ?? []
            let drop = max(lines.count / 2, 1)
            let before = fileSize(file)
            guard (try? Data(lines.dropFirst(drop).map { "\($0)\n" }.joined().utf8).write(to: file)) != nil else { return }
            totalBytes -= before - fileSize(file)
            record.droppedCount += min(drop, lines.count)
            write(record)
        }
    }

    // MARK: - Files

    private func readEntries(_ sessionId: String) -> [Entry] {
        guard let text = try? String(contentsOf: entriesURL(sessionId), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let kind = line.first.flatMap(EntryKind.init(rawValue:)),
                  let tab = line.firstIndex(of: "\t"),
                  let millis = Int64(line[line.index(after: line.startIndex)..<tab]),
                  // A line cut off by a crash is not valid JSON; skip it. JSON escapes tabs, so a second tab
                  // means a cut-off line ran into the next one.
                  line.hasSuffix("}"), line.lastIndex(of: "\t") == tab else {
                return nil
            }
            return Entry(kind: kind, timestampMillis: millis, json: String(line[line.index(after: tab)...]))
        }
    }

    private func write(_ record: Record) {
        records[record.session.id] = record
        let dir = sessionDir(record.session.id)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(record) else { return }
        let file = dir.appendingPathComponent(Self.sessionFile)
        totalBytes -= fileSize(file)
        if (try? data.write(to: file, options: .atomic)) != nil {
            totalBytes += data.count
        }
    }

    private func readRecord(in dir: URL) -> Record? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(Self.sessionFile)) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private func sessionDir(_ sessionId: String) -> URL {
        sessionsDir.appendingPathComponent(sessionId, isDirectory: true)
    }

    private func entriesURL(_ sessionId: String) -> URL {
        sessionDir(sessionId).appendingPathComponent(Self.entriesFile)
    }

    private func contents(of dir: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    }

    private func fileSize(_ url: URL) -> Int {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    private func size(of dir: URL) -> Int {
        guard let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }
        return enumerator.compactMap { $0 as? URL }.reduce(0) { total, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            return total + (values?.isRegularFile == true ? values?.fileSize ?? 0 : 0)
        }
    }
}
