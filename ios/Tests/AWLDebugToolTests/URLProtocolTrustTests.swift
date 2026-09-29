import XCTest
@testable import AWLDebugTool

final class URLProtocolTrustTests: XCTestCase {
    
    private let timeout: TimeInterval = 20
    
    override func setUp() {
        super.setUp()
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func loggedSession(delegate: URLSessionDelegate? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    
    private func load(_ urlString: String, delegate: URLSessionDelegate? = nil) -> (HTTPURLResponse?, Error?) {
        let session = loggedSession(delegate: delegate)
        defer { session.invalidateAndCancel() }
        
        let expectation = expectation(description: urlString)
        var result: (HTTPURLResponse?, Error?) = (nil, nil)
        var request = URLRequest(url: URL(string: urlString)!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: request) { _, response, error in
            result = (response as? HTTPURLResponse, error)
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: timeout)
        return result
    }
    
    func testValidCertificateSucceeds() {
        let (response, error) = load("https://badssl.com")
        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
    }
    
    func testSelfSignedCertificateFails() {
        let (response, error) = load("https://self-signed.badssl.com")
        XCTAssertNil(response)
        XCTAssertNotNil(error)
    }
    
    func testExpiredCertificateFails() {
        let (response, error) = load("https://expired.badssl.com")
        XCTAssertNil(response)
        XCTAssertNotNil(error)
    }
    
    func testAppDelegateRejectingTrustFailsValidHost() {
        let delegate = TrustDelegate(acceptServerTrust: false)
        let (response, error) = load("https://badssl.com", delegate: delegate)
        XCTAssertTrue(delegate.didReceiveServerTrustChallenge)
        XCTAssertNil(response)
        XCTAssertEqual((error as? URLError)?.code, .cancelled)
    }
    
    func testAppDelegateAcceptingTrustSucceedsSelfSignedHost() {
        let delegate = TrustDelegate(acceptServerTrust: true)
        let (response, error) = load("https://self-signed.badssl.com", delegate: delegate)
        XCTAssertTrue(delegate.didReceiveServerTrustChallenge)
        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
    }
}

private final class TrustDelegate: NSObject, URLSessionDelegate {
    
    let acceptServerTrust: Bool
    private(set) var didReceiveServerTrustChallenge = false
    
    init(acceptServerTrust: Bool) {
        self.acceptServerTrust = acceptServerTrust
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        didReceiveServerTrustChallenge = true
        if acceptServerTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
