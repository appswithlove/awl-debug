import XCTest
@testable import AWLDebugTool

final class CurlTests: XCTestCase {
    
    private func log(method: String, url: String, headers: [NetworkLog.Header] = [], body: NetworkLog.Body? = nil) -> NetworkLog {
        var log = NetworkLog(id: UUID(), method: method, url: url, date: Date(), duration: 0, statusCode: 200)
        log.requestHeaders = headers
        log.requestBody = body
        return log
    }
    
    func testFixture() {
        let log = log(method: "POST",
                      url: "https://api.example.com/v1/items?page=2",
                      headers: [.init(name: "Content-Type", value: "application/json"),
                                .init(name: "Authorization", value: "[REDACTED]")],
                      body: .init(text: #"{"name":"Test"}"#, contentType: "application/json", originalBytes: 15))
        
        XCTAssertEqual(log.curlCommand, """
            curl -X POST 'https://api.example.com/v1/items?page=2' \\
              -H 'Content-Type: application/json' \\
              -H 'Authorization: [REDACTED]' \\
              --data-raw '{"name":"Test"}'
            """)
    }
    
    func testGetWithoutBodyOmitsMethod() {
        XCTAssertEqual(log(method: "GET", url: "https://api.example.com/").curlCommand, "curl 'https://api.example.com/'")
    }
    
    func testSingleQuotesAreEscaped() {
        let log = log(method: "PUT", url: "https://api.example.com/", body: .init(text: "it's", contentType: "text/plain", originalBytes: 4))
        XCTAssertEqual(log.curlCommand, "curl -X PUT 'https://api.example.com/' \\\n  --data-raw 'it'\\''s'")
    }
    
    func testTruncatedAndPlaceholderBodiesAreNotIncluded() {
        let truncated = log(method: "POST", url: "https://api.example.com/", body: .init(text: "abc", contentType: "text/plain", originalBytes: 10, truncated: true))
        XCTAssertEqual(truncated.curlCommand, "curl -X POST 'https://api.example.com/'\n# body not included: truncated")
        
        let stream = log(method: "POST", url: "https://api.example.com/", body: NetworkRedactor.placeholderBody("(stream, not captured)", contentType: nil, totalBytes: 0))
        XCTAssertEqual(stream.curlCommand, "curl -X POST 'https://api.example.com/'\n# body not included: (stream, not captured)")
    }
}
