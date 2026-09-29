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
        XCTAssertEqual(log.requestBody?.text, #"{"password":"[REDACTED]"}"#)
        XCTAssertEqual(log.redactedCount, 7)
        XCTAssertEqual(server.receivedBody("/login"), request.httpBody)
        
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
    
    func testRequestBodyStreamIsCaptured() throws {
        var request = URLRequest(url: server.url("/upload"))
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(data: Data("streamed".utf8))
        
        let log = try loadAndFetchLog(request)
        
        XCTAssertEqual(log.requestBody?.text, "streamed")
        XCTAssertEqual(log.requestBytes, 8)
        XCTAssertEqual(server.receivedBody("/upload"), Data("streamed".utf8))
    }
    
    func testLargeUploadArrivesCompletely() throws {
        let body = Data(Array(repeating: Array(0...UInt8.max), count: 8 * 1024).joined())
        var request = URLRequest(url: server.url("/upload"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let log = try loadAndFetchLog(request)
        
        XCTAssertEqual(server.receivedBody("/upload"), body)
        XCTAssertEqual(log.requestBody?.text, "(binary, 2097152 bytes)")
        XCTAssertEqual(log.requestBytes, body.count)
    }
    
    func testLargeTextStreamIsTruncatedAndArrivesCompletely() throws {
        let body = Data(String(repeating: "0123456789abcdef", count: 128 * 1024).utf8)
        var request = URLRequest(url: server.url("/upload"))
        request.httpMethod = "PUT"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(data: body)
        
        let log = try loadAndFetchLog(request)
        
        XCTAssertEqual(server.receivedBody("/upload"), body)
        XCTAssertEqual(log.requestBody?.truncated, true)
        XCTAssertEqual(log.requestBody?.originalBytes, body.count)
        XCTAssertEqual(log.requestBody?.text, String(repeating: "0123456789abcdef", count: 16 * 1024))
    }
    
    func testMultipartRequestBodyIsCaptured() throws {
        let boundary = "b0undary"
        let file = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"password\"\r\n\r\nhunter2\r\n".utf8))
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhello\r\n".utf8))
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"avatar\"; filename=\"a.png\"\r\nContent-Type: image/png\r\n\r\n".utf8))
        body.append(file)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: server.url("/multipart"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let log = try loadAndFetchLog(request)
        let text = try XCTUnwrap(log.requestBody?.text)
        
        XCTAssertEqual(server.receivedBody("/multipart"), body)
        XCTAssertTrue(text.contains("[REDACTED]"))
        XCTAssertTrue(text.contains("hello"))
        XCTAssertTrue(text.contains("(file a.png, 6 bytes)"))
        XCTAssertFalse(text.contains("hunter2"))
    }
    
    func testStreamContentTypeRequestBodyIsNotRead() throws {
        var request = URLRequest(url: server.url("/ndjson"))
        request.httpMethod = "POST"
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(data: Data("{}\n{}\n".utf8))
        
        let log = try loadAndFetchLog(request)
        
        XCTAssertEqual(log.requestBody?.text, "(stream, not captured)")
        XCTAssertEqual(server.receivedBody("/ndjson"), Data("{}\n{}\n".utf8))
    }
    
    func testConfiguredStreamTypeRequestBodyIsNotRead() {
        let request = NSMutableURLRequest(url: server.url("/grpc"))
        request.setValue("application/grpc-web+proto", forHTTPHeaderField: "Content-Type")
        request.httpBodyStream = InputStream(data: Data([1, 2, 3]))
        
        let configured = AWLDebugURLProtocol.RequestInfo(request: request, config: .init(streamContentTypes: ["application/grpc-web+proto"]))
        let unconfigured = AWLDebugURLProtocol.RequestInfo(request: request, config: .init())
        
        XCTAssertNil(configured.requestBodyReadLimit)
        XCTAssertEqual(unconfigured.requestBodyReadLimit, 256 * 1024)
        XCTAssertNil(AWLDebugURLProtocol.RequestInfo(request: request, config: .init(captureBodies: false)).requestBodyReadLimit)
    }
}
