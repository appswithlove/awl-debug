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
        
        let logged = expectation(description: "logged")
        DispatchQueue.main.async {
            let statuses = AWLDebugTool.shared.networkLogger.networkTraffic
                .filter { $0.url.hasPrefix(self.server.url("/").absoluteString) }
                .map(\.statusCode)
            XCTAssertEqual(statuses.suffix(2), [302, 200])
            logged.fulfill()
        }
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
