import Security
import XCTest
@testable import AWLDebugTool

/// The capture's `URLProtocol` leaves server trust to the system and the app: it accepts nothing the app would reject,
/// and the app's own decision (e.g. certificate pinning) is used. Runs against a local HTTPS server, no internet needed.
final class URLProtocolTrustTests: XCTestCase {

    private let timeout: TimeInterval = 20

    private func loggedSession(delegate: URLSessionDelegate? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private func load(_ url: URL, delegate: URLSessionDelegate? = nil) -> (HTTPURLResponse?, Error?) {
        let session = loggedSession(delegate: delegate)
        defer { session.invalidateAndCancel() }

        let expectation = expectation(description: url.absoluteString)
        var result: (HTTPURLResponse?, Error?) = (nil, nil)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        session.dataTask(with: request) { _, response, error in
            result = (response as? HTTPURLResponse, error)
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: timeout)
        return result
    }

    func testCertificateTheAppTrustsSucceeds() throws {
        let identity = try TLSFixture.identity(.valid)
        let server = try LocalHTTPServer(tlsIdentity: identity)
        defer { server.stop() }
        let delegate = TrustDelegate(decision: .evaluate(anchor: try TLSFixture.certificate(of: identity)))
        let (response, error) = load(server.url("/"), delegate: delegate)
        XCTAssertTrue(delegate.didReceiveServerTrustChallenge)
        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testSelfSignedCertificateFails() throws {
        let server = try LocalHTTPServer(tlsIdentity: TLSFixture.identity(.valid))
        defer { server.stop() }
        let (response, error) = load(server.url("/"))
        XCTAssertNil(response)
        XCTAssertNotNil(error)
        XCTAssertEqual(server.hitCount("/"), 0, "no request is sent over an untrusted connection")
    }

    func testExpiredCertificateFails() throws {
        let identity = try TLSFixture.identity(.expired)
        let server = try LocalHTTPServer(tlsIdentity: identity)
        defer { server.stop() }
        // The app trusts the certificate itself, so only its expiry makes the evaluation fail.
        let delegate = TrustDelegate(decision: .evaluate(anchor: try TLSFixture.certificate(of: identity)))
        let (response, error) = load(server.url("/"), delegate: delegate)
        XCTAssertTrue(delegate.didReceiveServerTrustChallenge)
        XCTAssertNil(response)
        XCTAssertNotNil(error)
        XCTAssertEqual(server.hitCount("/"), 0)
    }

    func testAppDelegateRejectingTrustFailsValidHost() throws {
        let server = try LocalHTTPServer(tlsIdentity: TLSFixture.identity(.valid))
        defer { server.stop() }
        let delegate = TrustDelegate(decision: .reject)
        let (response, error) = load(server.url("/"), delegate: delegate)
        XCTAssertTrue(delegate.didReceiveServerTrustChallenge)
        XCTAssertNil(response)
        XCTAssertEqual((error as? URLError)?.code, .cancelled)
        XCTAssertEqual(server.hitCount("/"), 0)
    }

    func testAppDelegateAcceptingTrustSucceedsSelfSignedHost() throws {
        let server = try LocalHTTPServer(tlsIdentity: TLSFixture.identity(.valid))
        defer { server.stop() }
        let delegate = TrustDelegate(decision: .accept)
        let (response, error) = load(server.url("/"), delegate: delegate)
        XCTAssertTrue(delegate.didReceiveServerTrustChallenge)
        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(server.hitCount("/"), 1)
    }
}

/// Self-signed test certificates for `localhost` and `127.0.0.1` (RSA 2048, SHA-256, server auth) with their keys, in
/// `Fixtures/tls-*.p12`. `valid` runs from 2019-06-01 to 2119-06-01: issued before July 2019, so Apple's 825-day limit
/// for server certificates does not apply. `expired` ran out on 2019-02-01. Made with OpenSSL 3:
///
/// ```
/// openssl req -x509 -newkey rsa:2048 -sha256 -nodes -keyout key.pem -out cert.pem -subj /CN=localhost \
///   -not_before 20190601000000Z -not_after 21190601000000Z \
///   -addext subjectAltName=DNS:localhost,IP:127.0.0.1 -addext extendedKeyUsage=serverAuth \
///   -addext keyUsage=critical,digitalSignature,keyEncipherment -addext basicConstraints=critical,CA:FALSE
/// openssl pkcs12 -export -legacy -in cert.pem -inkey key.pem -out tls-localhost.p12 -passout pass:awl-debug-tests
/// ```
private enum TLSFixture {
    enum Certificate: String {
        case valid = "tls-localhost"
        case expired = "tls-localhost-expired"
    }

    static func identity(_ certificate: Certificate) throws -> SecIdentity {
        let url = try XCTUnwrap(Bundle.module.url(forResource: certificate.rawValue, withExtension: "p12", subdirectory: "Fixtures"))
        let options = [kSecImportExportPassphrase as String: "awl-debug-tests"] as CFDictionary
        var items: CFArray?
        let status = SecPKCS12Import(try Data(contentsOf: url) as CFData, options, &items)
        XCTAssertEqual(status, errSecSuccess)
        let item = try XCTUnwrap((items as? [[String: Any]])?.first?[kSecImportItemIdentity as String])
        return item as! SecIdentity
    }

    static func certificate(of identity: SecIdentity) throws -> SecCertificate {
        var certificate: SecCertificate?
        XCTAssertEqual(SecIdentityCopyCertificate(identity, &certificate), errSecSuccess)
        return try XCTUnwrap(certificate)
    }
}

private final class TrustDelegate: NSObject, URLSessionDelegate {

    enum Decision {
        case accept
        case reject
        /// Trusts only `anchor` (pinning) and leaves every other check to the system, e.g. the validity period.
        case evaluate(anchor: SecCertificate)
    }

    let decision: Decision
    private(set) var didReceiveServerTrustChallenge = false

    init(decision: Decision) {
        self.decision = decision
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        didReceiveServerTrustChallenge = true
        switch decision {
        case .accept:
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        case .reject:
            completionHandler(.cancelAuthenticationChallenge, nil)
        case .evaluate(let anchor):
            SecTrustSetAnchorCertificates(serverTrust, [anchor] as CFArray)
            SecTrustSetAnchorCertificatesOnly(serverTrust, true)
            if SecTrustEvaluateWithError(serverTrust, nil) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }
}
