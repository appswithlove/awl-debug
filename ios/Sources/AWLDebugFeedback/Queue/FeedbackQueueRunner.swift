//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Combine
import Network
import UIKit

/// The app's feedback queue: retries on start, when the app becomes active, when the network changes
/// and when the backoff of a queued report has passed.
@MainActor
final class FeedbackQueueRunner: ObservableObject {
    static let shared = FeedbackQueueRunner(queue: nil)

    @Published private(set) var pendingCount = 0

    private var storedQueue: FeedbackQueue?
    private var pathMonitor: NWPathMonitor?
    private var lastPath: NWPath?
    private var didBecomeActive: AnyCancellable?
    private var timer: Task<Void, Never>?

    init(queue: FeedbackQueue?) {
        storedQueue = queue
    }

    var queue: FeedbackQueue {
        if let storedQueue {
            return storedQueue
        }
        let queue = FeedbackQueue(directory: FeedbackQueue.defaultDirectory) { [weak self] count in
            await self?.update(pendingCount: count)
        }
        storedQueue = queue
        return queue
    }

    /// Starts the triggers once and retries right away (app start).
    func start() {
        guard pathMonitor == nil else {
            return
        }
        didBecomeActive = NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.retry(ignoringBackoff: false) }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.networkChanged(to: path) }
        }
        monitor.start(queue: DispatchQueue(label: "AWLDebugFeedback.FeedbackQueueRunner"))
        pathMonitor = monitor
        retry(ignoringBackoff: true)
    }

    func submit(_ request: URLRequest) async -> FeedbackQueue.SubmitResult {
        let result = await queue.submit(request)
        if result == .queued {
            await scheduleTimer()
        }
        return result
    }

    func retry(ignoringBackoff: Bool) {
        let queue = queue
        Task {
            await queue.retry(ignoringBackoff: ignoringBackoff)
            await scheduleTimer()
        }
    }

    private func networkChanged(to path: NWPath) {
        defer { lastPath = path }
        // The first update only reports the current path; start() already retried.
        guard let lastPath, path.status == .satisfied, path != lastPath else {
            return
        }
        retry(ignoringBackoff: true)
    }

    private func update(pendingCount: Int) {
        self.pendingCount = pendingCount
    }

    private func scheduleTimer() async {
        timer?.cancel()
        guard let nextAttemptAt = await queue.nextAttemptAt else {
            return
        }
        timer = Task { [weak self] in
            let delay = max(nextAttemptAt.timeIntervalSinceNow, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            self?.retry(ignoringBackoff: false)
        }
    }
}
