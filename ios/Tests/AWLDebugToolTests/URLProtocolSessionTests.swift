import XCTest
@testable import AWLDebugTool

final class URLProtocolSessionTests: XCTestCase {
    
    private var server: LocalHTTPServer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        server = try LocalHTTPServer()
    }
    
    override func tearDown() {
        server.stop()
        super.tearDown()
    }
    
    private func loggedConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        return configuration
    }
    
    private func load(_ request: URLRequest, configuration: URLSessionConfiguration, delegate: URLSessionDelegate? = nil) -> (Data?, HTTPURLResponse?, Error?) {
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        
        let expectation = expectation(description: request.url?.absoluteString ?? "")
        var result: (Data?, HTTPURLResponse?, Error?) = (nil, nil, nil)
        session.dataTask(with: request) { data, response, error in
            result = (data, response as? HTTPURLResponse, error)
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 10)
        return result
    }
    
    func testRequestTimeoutIsHonoured() {
        server.route("/hang", nil)
        var request = URLRequest(url: server.url("/hang"))
        request.timeoutInterval = 1
        
        let start = Date()
        let (_, _, error) = load(request, configuration: loggedConfiguration())
        
        XCTAssertEqual((error as? URLError)?.code, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
    
    func testSessionTimeoutIsHonoured() {
        server.route("/hang", nil)
        let configuration = loggedConfiguration()
        configuration.timeoutIntervalForRequest = 1
        
        let start = Date()
        let (_, _, error) = load(URLRequest(url: server.url("/hang")), configuration: configuration)
        
        XCTAssertEqual((error as? URLError)?.code, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
    
    func testCacheableResponseIsNotServedFromSharedCache() {
        server.route("/cacheable", .init(headers: [("Cache-Control", "max-age=600")]))
        let configuration = loggedConfiguration()
        configuration.urlCache = nil
        
        for _ in 0..<2 {
            let (_, response, error) = load(URLRequest(url: server.url("/cacheable")), configuration: configuration)
            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, 200)
        }
        XCTAssertEqual(server.hitCount("/cacheable"), 2)
    }
    
    func testRedirectIsFollowedExactlyOnce() {
        server.route("/redirect", .init(status: "302 Found", headers: [("Location", "/ok")], body: Data()))
        
        let (data, response, error) = load(URLRequest(url: server.url("/redirect")), configuration: loggedConfiguration())
        
        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.url, server.url("/ok"))
        XCTAssertEqual(data, Data("ok".utf8))
        XCTAssertEqual(server.hitCount("/redirect"), 1)
        XCTAssertEqual(server.hitCount("/ok"), 1)
        
        // Logs reach the list asynchronously, in batches.
        let logged = expectation(description: "logged")
        func poll() {
            let statuses = AWLDebugTool.shared.networkLogger.networkTraffic
                .filter { $0.url.hasPrefix(self.server.url("/").absoluteString) }
                .map(\.statusCode)
            if statuses.count >= 2 {
                XCTAssertEqual(statuses.suffix(2), [302, 200])
                logged.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            }
        }
        DispatchQueue.main.async(execute: poll)
        wait(for: [logged], timeout: 2)
    }
    
    func testAppRedirectDelegateIsConsulted() {
        server.route("/redirect", .init(status: "302 Found", headers: [("Location", "/ok")], body: Data()))
        let delegate = BlockingRedirectDelegate()
        
        let (_, response, error) = load(URLRequest(url: server.url("/redirect")), configuration: loggedConfiguration(), delegate: delegate)
        
        XCTAssertNil(error)
        XCTAssertTrue(delegate.didReceiveRedirect)
        XCTAssertEqual(response?.statusCode, 302)
        XCTAssertEqual(server.hitCount("/ok"), 0)
    }
    
    func testAppSessionCacheAnswersRepeatedRequests() {
        server.route("/cached", .init(headers: [("Cache-Control", "max-age=600")]))
        let configuration = loggedConfiguration()
        configuration.urlCache = URLCache(memoryCapacity: 1_000_000, diskCapacity: 0)
        
        for policy in [URLRequest.CachePolicy.useProtocolCachePolicy, .useProtocolCachePolicy, .returnCacheDataDontLoad] {
            let (data, response, error) = load(URLRequest(url: server.url("/cached"), cachePolicy: policy), configuration: configuration)
            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, 200)
            XCTAssertEqual(data, Data("ok".utf8))
        }
        XCTAssertEqual(server.hitCount("/cached"), 1)
    }
    
    func testAppSessionCookieSettingsApply() {
        let storage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "awl-debug-tests-\(UUID())")
        storage.setCookie(HTTPCookie(properties: [.name: "app", .value: "1", .domain: "127.0.0.1", .path: "/"])!)
        let shared = HTTPCookie(properties: [.name: "shared", .value: "1", .domain: "127.0.0.1", .path: "/"])!
        HTTPCookieStorage.shared.setCookie(shared)
        defer { HTTPCookieStorage.shared.deleteCookie(shared) }
        
        let ownStorage = loggedConfiguration()
        ownStorage.httpCookieStorage = storage
        _ = load(URLRequest(url: server.url("/own")), configuration: ownStorage)
        XCTAssertEqual(server.receivedHeaders("/own")["cookie"], "app=1")
        
        let noCookies = loggedConfiguration()
        noCookies.httpCookieStorage = .shared
        noCookies.httpShouldSetCookies = false
        _ = load(URLRequest(url: server.url("/none")), configuration: noCookies)
        XCTAssertNil(server.receivedHeaders("/none")["cookie"])
    }
    
    func testOtherSchemesReachTheAppsOwnProtocol() {
        let configuration = loggedConfiguration()
        configuration.protocolClasses = [AWLDebugURLProtocol.self, AppSchemeProtocol.self]
        
        let (data, _, error) = load(URLRequest(url: URL(string: "awltest://resource")!), configuration: configuration)
        
        XCTAssertNil(error)
        XCTAssertEqual(data, Data("app protocol".utf8))
    }
    
    /// The app decides on a busy delegate queue; the redirect must still be followed instead of returning the 302.
    func testRedirectIsFollowedWhenTheDelegateQueueIsBusy() {
        server.route("/redirect", .init(status: "302 Found", headers: [("Location", "/ok")], body: Data()))
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: loggedConfiguration(), delegate: FollowingRedirectDelegate(), delegateQueue: queue)
        defer { session.invalidateAndCancel() }
        let done = expectation(description: "done")
        var status: Int?
        session.dataTask(with: server.url("/redirect")) { _, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode
            done.fulfill()
        }.resume()
        queue.addOperation { Thread.sleep(forTimeInterval: 0.8) }
        wait(for: [done], timeout: 10)
        
        XCTAssertEqual(status, 200)
        XCTAssertEqual(server.hitCount("/ok"), 1)
    }
    
    /// The review scenario: the app decides about the redirect asynchronously, later than the protocol's grace period.
    func testSlowAsyncRedirectDecisionIsHonoured() {
        server.route("/redirect", .init(status: "302 Found", headers: [("Location", "/ok")], body: Data()))
        for follows in [true, false] {
            let delegate = SlowRedirectDelegate(follows: follows, delay: 0.8)
            let (_, response, error) = load(URLRequest(url: server.url("/redirect")), configuration: loggedConfiguration(), delegate: delegate)
            
            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, follows ? 200 : 302, "follows: \(follows)")
        }
        XCTAssertEqual(server.hitCount("/ok"), 1)
    }
    
    func testClientIsCalledOnStartLoadingThread() {
        let client = ThreadRecordingClient()
        let finished = expectation(description: "finished")
        client.onFinish = { finished.fulfill() }
        
        let loaderThread = Thread { [server] in
            let urlProtocol = AWLDebugURLProtocol(request: URLRequest(url: server!.url("/ok")), cachedResponse: nil, client: client)
            client.expectedThread = Thread.current
            urlProtocol.startLoading()
            while !client.isFinished {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
            }
            urlProtocol.stopLoading()
        }
        loaderThread.start()
        wait(for: [finished], timeout: 10)
        
        XCTAssertEqual(client.callbacks, ["response", "data", "finish"])
        XCTAssertTrue(client.allOnExpectedThread)
    }
}

private final class ThreadRecordingClient: NSObject, URLProtocolClient {
    
    var expectedThread: Thread?
    var onFinish: (() -> Void)?
    private(set) var callbacks: [String] = []
    private(set) var allOnExpectedThread = true
    private(set) var isFinished = false
    
    private func record(_ callback: String) {
        callbacks.append(callback)
        allOnExpectedThread = allOnExpectedThread && Thread.current == expectedThread
    }
    
    private func finish(_ callback: String) {
        record(callback)
        isFinished = true
        onFinish?()
    }
    
    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) { record("redirect") }
    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) { record("cached") }
    func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) { record("response") }
    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) { record("data") }
    func urlProtocolDidFinishLoading(_ protocol: URLProtocol) { finish("finish") }
    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: Error) { finish("error") }
    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) { record("challenge") }
    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) { record("cancelChallenge") }
}

private final class BlockingRedirectDelegate: NSObject, URLSessionTaskDelegate {
    
    private(set) var didReceiveRedirect = false
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        didReceiveRedirect = true
        completionHandler(nil)
    }
}

private final class FollowingRedirectDelegate: NSObject, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request)
    }
}

/// An app's own protocol for a custom scheme.
private final class AppSchemeProtocol: URLProtocol {
    
    override class func canInit(with request: URLRequest) -> Bool { request.url?.scheme == "awltest" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        let response = URLResponse(url: request.url!, mimeType: "text/plain", expectedContentLength: 12, textEncodingName: nil)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("app protocol".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
}

/// Decides about a redirect on another queue after `delay`.
private final class SlowRedirectDelegate: NSObject, URLSessionTaskDelegate {
    
    private let follows: Bool
    private let delay: TimeInterval
    
    init(follows: Bool, delay: TimeInterval) {
        self.follows = follows
        self.delay = delay
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [follows] in
            completionHandler(follows ? request : nil)
        }
    }
}
