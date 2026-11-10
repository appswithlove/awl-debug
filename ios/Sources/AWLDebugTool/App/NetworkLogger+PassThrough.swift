import Foundation

extension NetworkLogger {
    /// Redacts finished requests off the URL loading thread and the main thread.
    static let captureQueue = DispatchQueue(label: "AWLDebugTool.NetworkCapture", qos: .utility)
}

/// Which requests `AWLDebugURLProtocol` leaves to the system. Loading them through the protocol would break them
/// (WebSockets) or hold their whole transfer in a second request (streams, downloads, large uploads).
enum PassThrough {

    static func isPassedThrough(_ task: URLSessionTask, request: URLRequest) -> Bool {
        if task is URLSessionWebSocketTask || task is URLSessionDownloadTask || task is URLSessionStreamTask {
            return true
        }
        if task is URLSessionUploadTask && !isSmallUpload(request) {
            return true
        }
        return isLongLived(request)
    }

    /// WebSocket handshakes and Server-Sent Events, also for loaders that only ask about the request.
    static func isLongLived(_ request: URLRequest) -> Bool {
        let scheme = request.url?.scheme?.lowercased()
        if scheme == "ws" || scheme == "wss" || request.value(forHTTPHeaderField: "Upgrade") != nil {
            return true
        }
        return request.value(forHTTPHeaderField: "Accept")?.lowercased().contains("text/event-stream") == true
    }

    /// Upload tasks carry their size as `Content-Length`; without one the body is streamed.
    private static func isSmallUpload(_ request: URLRequest) -> Bool {
        guard let length = request.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init) else {
            return false
        }
        return length <= NetworkRedactor.maxRedactableBytes
    }
}

/// Logs a task left to the system from its metadata: URL, headers, status, duration, sizes and error. It only observes
/// the task's `state`, so the connection is untouched. WebSockets appear in the list once they are closed.
final class PassThroughLogger: NSObject {

    private static var associationKey: UInt8 = 0

    private let requestInfo: AWLDebugURLProtocol.RequestInfo
    private let lock = NSLock()
    private var observation: NSKeyValueObservation?
    private var isFinished = false

    private init(request: URLRequest, config: AWLDebugConfig.NetworkConfig) {
        requestInfo = AWLDebugURLProtocol.RequestInfo(request: request as NSURLRequest, config: config)
    }

    static func observe(_ task: URLSessionTask, request: URLRequest, config: AWLDebugConfig.NetworkConfig) {
        objc_sync_enter(task)
        defer { objc_sync_exit(task) }
        // URLSession may ask for the same task more than once.
        guard objc_getAssociatedObject(task, &associationKey) == nil else {
            return
        }
        let logger = PassThroughLogger(request: task is URLSessionWebSocketTask ? webSocketRequest(request) : request, config: config)
        objc_setAssociatedObject(task, &associationKey, logger, .OBJC_ASSOCIATION_RETAIN)
        let observation = task.observe(\.state, options: [.initial, .new]) { task, _ in
            guard task.state == .completed else { return }
            logger.finish(task)
        }
        logger.lock.lock()
        let isFinished = logger.isFinished
        if !isFinished {
            logger.observation = observation
        }
        logger.lock.unlock()
        if isFinished {
            observation.invalidate()
        }
    }

    /// URLSession hands out a WebSocket's requests with an http(s) URL; the log shows ws(s) like the app's code.
    private static func webSocketRequest(_ request: URLRequest) -> URLRequest {
        guard let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return request
        }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: break
        }
        var logged = request
        logged.url = components.url ?? url
        return logged
    }

    private func finish(_ task: URLSessionTask) {
        lock.lock()
        let isFirst = !isFinished
        isFinished = true
        let observation = observation
        self.observation = nil
        lock.unlock()
        guard isFirst else { return }
        observation?.invalidate()
        objc_setAssociatedObject(task, &Self.associationKey, nil, .OBJC_ASSOCIATION_RETAIN)

        let finishedAt = Date()
        let response = task.response
        let error = task.error
        let sentBytes = task.countOfBytesSent
        let receivedBytes = task.countOfBytesReceived
        NetworkLogger.captureQueue.async { [requestInfo] in
            requestInfo.finishPassThrough(response: response, error: error, sentBytes: sentBytes, receivedBytes: receivedBytes, finishedAt: finishedAt)
            AWLDebugTool.shared.networkLogger.enqueueNetworkLog(requestInfo.makeLog())
        }
    }
}
