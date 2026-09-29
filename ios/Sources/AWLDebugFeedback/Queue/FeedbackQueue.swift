//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// Sends reports and keeps the ones that failed for a reason worth retrying (network, timeout, 5xx, 429)
/// in `directory`, one folder per report holding the exact request body. Retries back off from 30 s to 1 h
/// and respect `Retry-After`; at most `maxReports` reports or `maxBytes` are kept, the oldest are dropped first.
actor FeedbackQueue {
    enum SubmitResult: Equatable {
        case sent
        case queued
        case failed(FeedbackError)
    }

    static let minBackoff: TimeInterval = 30
    static let maxBackoff: TimeInterval = 60 * 60

    private static let entryFile = "report.json"
    private static let bodyFile = "body"
    private static let temporarySuffix = ".tmp"

    private let directory: URL
    private let session: URLSession
    private let now: @Sendable () -> Date
    private let maxReports: Int
    private let maxBytes: Int
    private let onPendingCountChange: @Sendable (Int) async -> Void
    private var isRetrying = false

    init(
        directory: URL,
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { Date() },
        maxReports: Int = 20,
        maxBytes: Int = 50 * 1024 * 1024,
        onPendingCountChange: @escaping @Sendable (Int) async -> Void = { _ in }
    ) {
        self.directory = directory
        self.session = session
        self.now = now
        self.maxReports = maxReports
        self.maxBytes = maxBytes
        self.onPendingCountChange = onPendingCountChange
    }

    /// `Library/Application Support/AWLDebug/feedback-queue/`: kept across launches, not a cache.
    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "AWLDebug/feedback-queue", directoryHint: .isDirectory)
    }

    /// Sends `request` once and queues it when the failure is worth retrying.
    func submit(_ request: URLRequest) async -> SubmitResult {
        do {
            try await FeedbackClient.send(request, session: session)
            return .sent
        } catch {
            guard error.error.isRetryable, enqueue(request, failure: error) else {
                return .failed(error.error)
            }
            await onPendingCountChange(entries().count)
            return .queued
        }
    }

    /// Sends queued reports, oldest first. With `ignoringBackoff` every report goes out unless the service
    /// asked to wait (`Retry-After`); otherwise only reports whose backoff has passed.
    func retry(ignoringBackoff: Bool) async {
        // The actor is reentrant while a request is in flight; a second pass would send the same reports again.
        guard !isRetrying else {
            return
        }
        isRetrying = true
        defer { isRetrying = false }
        removeLeftovers()
        for entry in entries() {
            let now = now()
            guard (ignoringBackoff ? entry.state.notBefore : entry.state.nextAttemptAt) <= now else {
                continue
            }
            guard let request = entry.request() else {
                remove(entry)
                continue
            }
            do {
                try await FeedbackClient.send(request, session: session)
                remove(entry)
            } catch where error.error.isRetryable {
                record(error, for: entry, at: now)
                // Still offline: the remaining reports would fail the same way.
                if error.error == .offline || error.error == .network {
                    break
                }
            } catch {
                remove(entry)
            }
        }
        await onPendingCountChange(entries().count)
    }

    var pendingCount: Int {
        entries().count
    }

    /// When the next queued report is due, `nil` when the queue is empty.
    var nextAttemptAt: Date? {
        entries().map(\.state.nextAttemptAt).min()
    }

    // MARK: - Storage

    private func enqueue(_ request: URLRequest, failure: FeedbackFailure) -> Bool {
        guard let body = request.httpBody, body.count <= maxBytes,
              let url = request.url,
              let key = request.value(forHTTPHeaderField: FeedbackClient.idempotencyHeader)
        else {
            return false
        }
        let now = now()
        let state = EntryState(
            idempotencyKey: key,
            url: url,
            headers: request.allHTTPHeaderFields ?? [:],
            createdAt: now,
            attempts: 0,
            nextAttemptAt: now,
            notBefore: now
        ).recordingFailure(failure, at: now)
        let fileManager = FileManager.default
        let temporary = directory.appending(path: key + Self.temporarySuffix, directoryHint: .isDirectory)
        let target = directory.appending(path: key, directoryHint: .isDirectory)
        do {
            try createDirectory()
            try? fileManager.removeItem(at: temporary)
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
            try body.write(to: temporary.appending(path: Self.bodyFile))
            try JSONEncoder().encode(state).write(to: temporary.appending(path: Self.entryFile))
            try? fileManager.removeItem(at: target)
            try fileManager.moveItem(at: temporary, to: target)
        } catch {
            try? fileManager.removeItem(at: temporary)
            return false
        }
        evictOldest()
        return true
    }

    private func createDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else {
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Reports are device-local and short-lived; they have no place in backups.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = directory
        try? directory.setResourceValues(values)
    }

    private func evictOldest() {
        var all = entries()
        var totalBytes = all.reduce(0) { $0 + $1.sizeBytes }
        while !all.isEmpty, all.count > maxReports || totalBytes > maxBytes {
            let oldest = all.removeFirst()
            totalBytes -= oldest.sizeBytes
            remove(oldest)
        }
    }

    private func record(_ failure: FeedbackFailure, for entry: Entry, at date: Date) {
        let state = entry.state.recordingFailure(failure, at: date)
        try? JSONEncoder().encode(state).write(to: entry.folder.appending(path: Self.entryFile), options: .atomic)
    }

    private func remove(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.folder)
    }

    /// Folders of writes interrupted by the app being killed.
    private func removeLeftovers() {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for folder in folders where folder.lastPathComponent.hasSuffix(Self.temporarySuffix)
            || !FileManager.default.fileExists(atPath: folder.appending(path: Self.entryFile).path) {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    /// Queued reports, oldest first.
    private func entries() -> [Entry] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders
            .filter { !$0.lastPathComponent.hasSuffix(Self.temporarySuffix) }
            .compactMap { folder in
                guard let data = try? Data(contentsOf: folder.appending(path: Self.entryFile)),
                      let state = try? JSONDecoder().decode(EntryState.self, from: data)
                else {
                    return nil
                }
                return Entry(folder: folder, state: state)
            }
            .sorted { $0.state.createdAt < $1.state.createdAt }
    }

    private struct Entry {
        let folder: URL
        let state: EntryState

        var sizeBytes: Int {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey]
            )) ?? []
            return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        }

        /// The original request, byte for byte.
        func request() -> URLRequest? {
            guard let body = try? Data(contentsOf: folder.appending(path: FeedbackQueue.bodyFile)) else {
                return nil
            }
            var request = URLRequest(url: state.url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.allHTTPHeaderFields = state.headers
            request.httpBody = body
            return request
        }
    }

    private struct EntryState: Codable {
        let idempotencyKey: String
        let url: URL
        let headers: [String: String]
        let createdAt: Date
        var attempts: Int
        var nextAttemptAt: Date
        /// Earliest time the service accepts another attempt (`Retry-After`).
        var notBefore: Date

        /// Schedules the next attempt: 30 s doubling to 1 h, never before `Retry-After`.
        func recordingFailure(_ failure: FeedbackFailure, at date: Date) -> EntryState {
            var state = self
            state.attempts += 1
            let backoff = min(FeedbackQueue.minBackoff * pow(2, Double(min(state.attempts - 1, 7))), FeedbackQueue.maxBackoff)
            state.notBefore = date.addingTimeInterval(TimeInterval(failure.retryAfterSeconds ?? 0))
            state.nextAttemptAt = max(date.addingTimeInterval(backoff), state.notBefore)
            return state
        }
    }
}
