import Foundation
import Network

/// Records sessions, requests and metric samples into `buffer` for remote reporting. All work runs on
/// `queue`, one task at a time, so callers never block on disk access.
///
/// A session starts with the first foreground (or the first captured request, if earlier) and ends
/// when the app goes to the background; returning within `sessionTimeout` continues it.
///
/// Batches go out every `flushInterval` in the foreground, when the app goes to the background, when the
/// network comes back and on `flush`.
final class RemoteReporter {
    struct Snapshot: Equatable {
        var sessionId: String?
        var upload = ReportingUploader.State()
    }

    static let sessionTimeout: TimeInterval = 30 * 60
    static let flushInterval: TimeInterval = 30

    let queue = DispatchQueue(label: "awl-debug.reporting", qos: .utility)
    let buffer: ReportingBuffer
    private let config: RemoteReportingConfig
    private let endpoint: String
    private let maxBodyBytes: Int
    private let now: () -> Int64
    private let uptime: () -> TimeInterval
    private var sampler: ReportingMetricsSampler?
    private var userIdentifier: String?
    private(set) var session: ReportingSession?
    private var backgroundSince: TimeInterval?
    let uploader: ReportingUploader?
    private var flushTimer: DispatchSourceTimer?
    private var pathMonitor: NWPathMonitor?
    private var path: NWPath?
    /// The panel's "Send session data" switch.
    private var isEnabled = true
    /// Called on `queue` whenever the session or the upload state changes.
    var onChange: ((Snapshot) -> Void)?

    init(config: RemoteReportingConfig,
         buffer: ReportingBuffer,
         appUserId: String?,
         now: @escaping () -> Int64 = { ReportingJSON.millis(Date()) },
         // Keeps counting while the device sleeps, unlike `systemUptime`, so a locked phone still ends the session.
         uptime: @escaping () -> TimeInterval = { TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000 },
         samplesMetrics: Bool = true,
         uploads: Bool = true) {
        self.config = config
        self.buffer = buffer
        self.now = now
        self.uptime = uptime
        var endpoint = config.endpoint.absoluteString
        while endpoint.hasSuffix("/") {
            endpoint.removeLast()
        }
        self.endpoint = endpoint
        maxBodyBytes = min(max(config.maxBodyBytes, 0), ReportingJSON.maxBodyBytes)
        userIdentifier = appUserId.map { ReportingJSON.userIdentifier(appKey: config.appKey, appUserId: $0) }
        uploader = uploads ? ReportingUploader(endpoint: endpoint, appKey: config.appKey, queue: queue, buffer: buffer, uptime: uptime) : nil
        uploader?.canSend = { [weak self] in self?.canSend ?? false }
        uploader?.onStateChange = { [weak self] _ in self?.publish() }
        if samplesMetrics {
            sampler = ReportingMetricsSampler(queue: queue) { [weak self] sample in
                self?.record(sample)
            }
        }
    }

    /// Seals sessions an earlier process left behind, so they go out with their own session object, and sends them.
    func start() {
        queue.async { [self] in
            for session in buffer.load() {
                buffer.seal(sessionId: session.id, finish: true)
            }
            if uploader != nil {
                startPathMonitor()
            }
            uploader?.send(ignoringBackoff: true)
        }
    }

    /// The panel's "Send session data" switch: off records and sends nothing.
    func setEnabled(_ enabled: Bool) {
        queue.async { [self] in
            isEnabled = enabled
            if enabled {
                uploader?.send(ignoringBackoff: true)
            }
        }
    }

    private var isRecording: Bool {
        isEnabled && uploader?.state.isStopped != true
    }

    private var canSend: Bool {
        guard isEnabled else { return false }
        guard config.onlyOnUnmeteredNetwork, let path else { return true }
        return !path.isExpensive && !path.isConstrained
    }

    func onForeground() {
        queue.async { [self] in
            let since = backgroundSince
            backgroundSince = nil
            if let current = session, since.map({ uptime() - $0 < Self.sessionTimeout }) ?? true {
                if current.endedAtMillis != nil {
                    var resumed = current
                    resumed.endedAtMillis = nil
                    update(resumed)
                }
            } else {
                if let current = session {
                    buffer.seal(sessionId: current.id, finish: true)
                }
                newSession()
            }
            sampler?.start()
            startFlushTimer()
        }
    }

    /// Ends the session and sends what is left; `completion` runs on `queue` once nothing is in flight.
    func onBackground(completion: (() -> Void)? = nil) {
        queue.async { [self] in
            backgroundSince = uptime()
            sampler?.stop()
            flushTimer?.cancel()
            flushTimer = nil
            if var current = session {
                current.endedAtMillis = now()
                update(current)
                buffer.seal(sessionId: current.id)
            }
            send(ignoringBackoff: true, completion: completion)
        }
    }

    func record(_ log: NetworkLog) {
        // The SDK's own requests to the service are never reported.
        guard log.url != endpoint, !log.url.hasPrefix(endpoint + "/") else { return }
        queue.async { [self] in
            guard isRecording, let json = ReportingJSON.networkLog(log, captureBodies: config.captureBodies, maxBodyBytes: maxBodyBytes)
                .flatMap(ReportingJSON.encode) else {
                return
            }
            buffer.append(sessionId: currentSession().id, timestampMillis: ReportingJSON.millis(log.date), kind: .network, json: json)
        }
    }

    func record(_ sample: ReportingMetricSample) {
        queue.async { [self] in
            guard isRecording, let json = ReportingJSON.metric(sample).flatMap(ReportingJSON.encode) else { return }
            buffer.append(sessionId: currentSession().id, timestampMillis: sample.timestampMillis, kind: .metric, json: json)
        }
    }

    func setUserIdentifier(_ appUserId: String?) {
        queue.async { [self] in
            userIdentifier = appUserId.map { ReportingJSON.userIdentifier(appKey: config.appKey, appUserId: $0) }
            if var current = session {
                current.userIdentifier = userIdentifier
                update(current)
            }
        }
    }

    /// Moves everything recorded so far into sealed batches and sends them. `completion` runs on `queue`.
    func flush(ignoringBackoff: Bool = true, completion: (() -> Void)? = nil) {
        queue.async { [self] in
            if let session {
                buffer.seal(sessionId: session.id)
            }
            send(ignoringBackoff: ignoringBackoff, completion: completion)
        }
    }

    private func send(ignoringBackoff: Bool, completion: (() -> Void)?) {
        guard let uploader else {
            completion?()
            return
        }
        uploader.send(ignoringBackoff: ignoringBackoff, completion: completion)
    }

    private func startFlushTimer() {
        guard uploader != nil, flushTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.flushInterval, repeating: Self.flushInterval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if let session = self.session {
                self.buffer.seal(sessionId: session.id)
            }
            self.send(ignoringBackoff: false, completion: nil)
        }
        timer.resume()
        flushTimer = timer
    }

    /// Sends right away when the device gets a (different) network again, e.g. after flight mode.
    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let previous = self.path
            self.path = path
            if let previous, path.status == .satisfied, path != previous {
                self.send(ignoringBackoff: true, completion: nil)
            }
        }
        monitor.start(queue: queue)
        pathMonitor = monitor
    }

    private func publish() {
        onChange?(Snapshot(sessionId: session?.id, upload: uploader?.state ?? .init()))
    }

    private func currentSession() -> ReportingSession {
        session ?? newSession()
    }

    @discardableResult
    private func newSession() -> ReportingSession {
        let created = ReportingSession.create(config: config, userIdentifier: userIdentifier, nowMillis: now())
        update(created)
        return created
    }

    private func update(_ updated: ReportingSession) {
        let isNew = updated.id != session?.id
        session = updated
        buffer.put(session: updated)
        if isNew {
            publish()
        }
    }

    deinit {
        flushTimer?.cancel()
        pathMonitor?.cancel()
    }
}
