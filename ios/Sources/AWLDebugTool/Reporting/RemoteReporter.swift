import Foundation

/// Records sessions, requests and metric samples into `buffer` for remote reporting. All work runs on
/// `queue`, one task at a time, so callers never block on disk access.
///
/// A session starts with the first foreground (or the first captured request, if earlier) and ends
/// when the app goes to the background; returning within `sessionTimeout` continues it.
final class RemoteReporter {
    static let sessionTimeout: TimeInterval = 30 * 60

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

    init(config: RemoteReportingConfig,
         buffer: ReportingBuffer,
         appUserId: String?,
         now: @escaping () -> Int64 = { ReportingJSON.millis(Date()) },
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         samplesMetrics: Bool = true) {
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
        if samplesMetrics {
            sampler = ReportingMetricsSampler(queue: queue) { [weak self] sample in
                self?.record(sample)
            }
        }
    }

    /// Seals sessions an earlier process left behind, so they go out with their own session object.
    func start() {
        queue.async { [self] in
            for session in buffer.load() {
                buffer.seal(sessionId: session.id, finish: true)
            }
        }
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
        }
    }

    func onBackground() {
        queue.async { [self] in
            backgroundSince = uptime()
            sampler?.stop()
            guard var current = session else { return }
            current.endedAtMillis = now()
            update(current)
            buffer.seal(sessionId: current.id)
        }
    }

    func record(_ log: NetworkLog) {
        // The SDK's own requests to the service are never reported.
        guard log.url != endpoint, !log.url.hasPrefix(endpoint + "/") else { return }
        queue.async { [self] in
            guard let json = ReportingJSON.networkLog(log, captureBodies: config.captureBodies, maxBodyBytes: maxBodyBytes)
                .flatMap(ReportingJSON.encode) else {
                return
            }
            buffer.append(sessionId: currentSession().id, timestampMillis: ReportingJSON.millis(log.date), kind: .network, json: json)
        }
    }

    func record(_ sample: ReportingMetricSample) {
        queue.async { [self] in
            guard let json = ReportingJSON.metric(sample).flatMap(ReportingJSON.encode) else { return }
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

    /// Moves everything recorded so far into sealed batches.
    func flush() {
        queue.async { [self] in
            if let session {
                buffer.seal(sessionId: session.id)
            }
        }
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
        session = updated
        buffer.put(session: updated)
    }
}
