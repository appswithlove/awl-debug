import Foundation

/// The URLSessions `AWLDebugURLProtocol` loads requests with: one per app session, configured like it, so cookies,
/// cache, credentials, proxy, TLS settings and connection reuse behave as without the tool.
final class InnerSessions {

    static let shared = InnerSessions()

    private struct Entry {
        weak var appSession: URLSession?
        let session: URLSession
    }

    private let lock = NSLock()
    private let delegate = InnerSessionDelegate()
    /// Keyed by the app session; `nil` (requests without a task) uses `fallback`.
    private var entries: [ObjectIdentifier: Entry] = [:]
    private lazy var fallback = makeSession(configuration: nil)

    /// The app's session that `task` belongs to. URLSession has no public accessor; without one the tool falls back
    /// to a default configuration.
    static func appSession(of task: URLSessionTask?) -> URLSession? {
        guard let task, (task as NSObject).responds(to: NSSelectorFromString("session")) else {
            return nil
        }
        return (task as NSObject).value(forKey: "session") as? URLSession
    }

    func session(for appSession: URLSession?) -> URLSession {
        guard let appSession else {
            return lock.withLock { fallback }
        }
        lock.lock()
        defer { lock.unlock() }
        if let entry = entries[ObjectIdentifier(appSession)], entry.appSession === appSession {
            return entry.session
        }
        removeEntriesOfReleasedSessions()
        let session = makeSession(configuration: appSession.configuration)
        entries[ObjectIdentifier(appSession)] = Entry(appSession: appSession, session: session)
        return session
    }

    func register(_ task: URLSessionTask, for handler: AWLDebugURLProtocol) {
        delegate.register(task, for: handler)
    }

    func unregister(_ task: URLSessionTask) {
        delegate.unregister(task)
    }

    private func removeEntriesOfReleasedSessions() {
        for (key, entry) in entries where entry.appSession == nil {
            entry.session.finishTasksAndInvalidate()
            entries[key] = nil
        }
    }

    /// `configuration` is a copy of the app session's; `nil` gives a default session without a cache.
    private func makeSession(configuration: URLSessionConfiguration?) -> URLSession {
        let configuration = configuration ?? {
            let configuration = URLSessionConfiguration.ephemeral
            // Without the app's configuration there is no app cache to use; the app's session stores what is forwarded.
            configuration.urlCache = nil
            return configuration
        }()
        configuration.protocolClasses = configuration.protocolClasses?.filter { ObjectIdentifier($0) != ObjectIdentifier(AWLDebugURLProtocol.self) }
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}

/// Routes the callbacks of the shared sessions to the protocol instance that started the task.
private final class InnerSessionDelegate: NSObject, URLSessionDataDelegate {

    private let lock = NSLock()
    private var handlers: [ObjectIdentifier: AWLDebugURLProtocol] = [:]

    func register(_ task: URLSessionTask, for handler: AWLDebugURLProtocol) {
        lock.withLock { handlers[ObjectIdentifier(task)] = handler }
    }

    func unregister(_ task: URLSessionTask) {
        _ = lock.withLock { handlers.removeValue(forKey: ObjectIdentifier(task)) }
    }

    private func handler(for task: URLSessionTask) -> AWLDebugURLProtocol? {
        lock.withLock { handlers[ObjectIdentifier(task)] }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handler(for: dataTask)?.urlSession(session, dataTask: dataTask, didReceive: data)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let handler = handler(for: dataTask) else {
            completionHandler(.cancel)
            return
        }
        handler.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        handler(for: task)?.urlSession(session, task: task, didCompleteWithError: error)
        unregister(task)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let handler = handler(for: task) else {
            completionHandler(nil)
            return
        }
        handler.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let handler = handler(for: task) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        handler.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(proposedResponse)
    }
}
