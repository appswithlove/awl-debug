import XCTest
@testable import AWLDebugTool

final class NetworkCaptureTests: XCTestCase {
    
    private var server: LocalHTTPServer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        server = try LocalHTTPServer()
    }
    
    override func tearDown() {
        server.stop()
        super.tearDown()
    }
    
    private func loadAndFetchLog(_ request: URLRequest) throws -> NetworkLog {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        
        let loaded = expectation(description: "loaded")
        session.dataTask(with: request) { _, _, error in
            XCTAssertNil(error)
            loaded.fulfill()
        }.resume()
        wait(for: [loaded], timeout: 10)
        
        let url = try XCTUnwrap(request.url?.absoluteString)
        var log: NetworkLog?
        let logged = expectation(description: "logged")
        func poll() {
            log = AWLDebugTool.shared.networkLogger.networkTraffic.last { $0.url.hasPrefix(url.components(separatedBy: "?")[0]) }
            if log == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            } else {
                logged.fulfill()
            }
        }
        DispatchQueue.main.async(execute: poll)
        wait(for: [logged], timeout: 5)
        return try XCTUnwrap(log)
    }
    
    func testSecretsAreRedactedEverywhere() throws {
        server.route("/login", .init(headers: [("Content-Type", "application/json"), ("Set-Cookie", "c=d")],
                                     body: Data(#"{"user":{"password":"p","items":[{"access_token":"t"}]}}"#.utf8)))
        var request = URLRequest(url: server.url("/login?token=abc&page=1"))
        request.httpMethod = "POST"
        request.setValue("Bearer x", forHTTPHeaderField: "Authorization")
        request.setValue("a=b", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"password":"hunter2"}"#.utf8)
        
        let log = try loadAndFetchLog(request)
        
        XCTAssertEqual(log.statusCode, 200)
        XCTAssertTrue(log.url.hasSuffix("/login?token=[REDACTED]&page=1"))
        XCTAssertEqual(log.requestHeaders.first { $0.name == "Authorization" }?.value, "[REDACTED]")
        XCTAssertEqual(log.requestHeaders.first { $0.name == "Cookie" }?.value, "[REDACTED]")
        XCTAssertEqual(log.responseHeaders.first { $0.name.lowercased() == "set-cookie" }?.value, "[REDACTED]")
        XCTAssertEqual(log.responseBody?.text, #"{"user":{"items":[{"access_token":"[REDACTED]"}],"password":"[REDACTED]"}}"#)
        // URLSession hands `httpBody` to URL protocols as `httpBodyStream`, which is never read.
        XCTAssertEqual(log.requestBody?.text, "(stream, not captured)")
        XCTAssertEqual(log.redactedCount, 6)
        
        for text in [log.curlCommand, log.exportText] {
            for secret in ["Bearer x", "a=b", "c=d", "abc", "hunter2", #""p""#, #""t""#] {
                XCTAssertFalse(text.contains(secret), "\(secret) leaked into \(text)")
            }
        }
    }
    
    func testEventStreamIsNotCaptured() throws {
        server.route("/events", .init(headers: [("Content-Type", "text/event-stream")], body: Data("data: 1\n\n".utf8)))
        
        let log = try loadAndFetchLog(URLRequest(url: server.url("/events")))
        
        XCTAssertEqual(log.responseBody?.text, "(stream, not captured)")
        XCTAssertEqual(log.responseBytes, 9)
    }
    
    func testNDJSONAndConfiguredStreamTypesAreNotRead() {
        let redactor = NetworkRedactor(config: .init(streamContentTypes: ["application/grpc-web"]))
        XCTAssertTrue(redactor.isStreamResponse(statusCode: 200, contentType: "application/x-ndjson"))
        XCTAssertTrue(redactor.isStreamResponse(statusCode: 200, contentType: "application/grpc-web; charset=utf-8"))
        XCTAssertTrue(redactor.isStreamResponse(statusCode: 101, contentType: nil))
        XCTAssertFalse(redactor.isStreamResponse(statusCode: 200, contentType: "application/json"))
    }
    
    func testRequestBodyStreamIsForwardedButNotCaptured() throws {
        var request = URLRequest(url: server.url("/upload"))
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: Data("streamed".utf8))
        
        let log = try loadAndFetchLog(request)
        
        XCTAssertEqual(log.requestBody?.text, "(stream, not captured)")
        XCTAssertEqual(server.hitCount("/upload"), 1)
    }
}
