import Foundation

/// Sends sealed batches to `POST /v1/sessions/batch`, oldest first, one at a time. Runs on the
/// reporter's queue, like the buffer it reads from.
///
/// A batch file keeps its bytes (and `batchId`) until the service accepted or rejected it for good, so a
/// retry after a network error, 5xx or 429 sends the same batch again. 400/413/415/422 drop the batch;
/// 401/403 stop sending until the next app start.
final class ReportingUploader {
    enum Problem: Equatable {
        /// 401: unknown or disabled app key.
        case unauthorized
        /// 403: remote reporting is off for the app in the dashboard.
        case disabledByServer
        /// The service rejected a batch for good; it was dropped.
        case rejected(status: Int)
    }

    struct State: Equatable {
        var pendingCount = 0
        var lastSentAt: Date?
        var problem: Problem?
        /// 401/403: nothing is sent until the next app start.
        var isStopped = false
    }

    static let minBackoff: TimeInterval = 30
    static let maxBackoff: TimeInterval = 60 * 60
    static let requestTimeout: TimeInterval = 20

    private let queue: DispatchQueue
    private let buffer: ReportingBuffer
    private let url: URL
    private let appKey: String
    private let session: URLSession
    private let uptime: () -> TimeInterval
    /// `false` while sending is not allowed, e.g. on a metered network with `onlyOnUnmeteredNetwork`.
    var canSend: () -> Bool = { true }
    /// Called on the queue whenever `state` changes.
    var onStateChange: ((State) -> Void)?

    private(set) var state = State() {
        didSet {
            if state != oldValue {
                onStateChange?(state)
            }
        }
    }
    private var isSending = false
    private var failures = 0
    private var nextAttemptAt: TimeInterval = 0
    private var retryAfterUntil: TimeInterval = 0
    private var completions: [() -> Void] = []

    init(endpoint: String, appKey: String, queue: DispatchQueue, buffer: ReportingBuffer,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.queue = queue
        self.buffer = buffer
        self.appKey = appKey
        self.uptime = uptime
        url = URL(string: endpoint + "/v1/sessions/batch")!
        session = URLSession(configuration: Self.sessionConfiguration())
    }

    deinit {
        session.invalidateAndCancel()
    }

    /// Its own ephemeral session without the SDK's `URLProtocol`: the SDK never captures its own traffic.
    static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = configuration.protocolClasses?.filter {
            ObjectIdentifier($0) != ObjectIdentifier(AWLDebugURLProtocol.self)
        }
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = requestTimeout
        return configuration
    }

    /// Call on the queue. Sends all sealed batches; `ignoringBackoff` skips the wait after failed attempts
    /// but never a `Retry-After`. `completion` runs on the queue once nothing is in flight anymore.
    func send(ignoringBackoff: Bool, completion: (() -> Void)? = nil) {
        if let completion {
            completions.append(completion)
        }
        guard !isSending else { return }
        sendNext(ignoringBackoff: ignoringBackoff)
    }

    /// Call on the queue after batches were sealed or dropped.
    func refreshPendingCount() {
        state.pendingCount = buffer.sealedBatches().count
    }

    private func sendNext(ignoringBackoff: Bool) {
        refreshPendingCount()
        let now = uptime()
        guard !state.isStopped,
              let batch = buffer.sealedBatches().first,
              now >= retryAfterUntil,
              ignoringBackoff || now >= nextAttemptAt,
              canSend() else {
            finish()
            return
        }
        guard let body = try? Data(contentsOf: batch) else {
            buffer.deleteBatch(batch)
            sendNext(ignoringBackoff: ignoringBackoff)
            return
        }
        isSending = true
        session.dataTask(with: request(body: body)) { [weak self] _, response, error in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode
            let retryAfter = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After")
            self.queue.async {
                self.isSending = false
                self.handle(status: error == nil ? status : nil, retryAfter: retryAfter, batch: batch)
            }
        }.resume()
    }

    private func request(body: Data) -> URLRequest {
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        request.setValue(appKey, forHTTPHeaderField: "X-App-Key")
        request.httpBody = body
        URLProtocol.setProperty(true, forKey: AWLDebugURLProtocol.Constants.SkipCaptureKey, in: request)
        return request as URLRequest
    }

    private func handle(status: Int?, retryAfter: String?, batch: URL) {
        switch status {
        case .some(200..<300):
            buffer.deleteBatch(batch)
            failures = 0
            nextAttemptAt = 0
            state.lastSentAt = Date()
            sendNext(ignoringBackoff: true)
        case .some(401), .some(403):
            state.problem = status == 401 ? .unauthorized : .disabledByServer
            state.isStopped = true
            finish()
        case .some(let status) where (400..<500).contains(status) && status != 408 && status != 429:
            // Sending it again cannot succeed (400, 413, 415, 422).
            buffer.deleteBatch(batch)
            state.problem = .rejected(status: status)
            sendNext(ignoringBackoff: true)
        default:
            failures += 1
            let now = uptime()
            let backoff = min(Self.minBackoff * pow(2, Double(min(failures - 1, 7))), Self.maxBackoff)
            nextAttemptAt = now + backoff
            if let delay = retryAfter.flatMap(Self.retryAfterSeconds) {
                retryAfterUntil = now + min(delay, Self.maxBackoff)
                nextAttemptAt = max(nextAttemptAt, retryAfterUntil)
            }
            finish()
        }
    }

    /// Seconds from a `Retry-After` value: delta seconds or an HTTP date.
    static func retryAfterSeconds(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let seconds = TimeInterval(trimmed) {
            return max(seconds, 0)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: trimmed).map { max($0.timeIntervalSinceNow, 0) }
    }

    private func finish() {
        refreshPendingCount()
        let completions = completions
        self.completions = []
        completions.forEach { $0() }
    }
}
