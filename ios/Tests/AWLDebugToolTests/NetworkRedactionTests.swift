import XCTest
@testable import AWLDebugTool

final class NetworkRedactionTests: XCTestCase {
    
    private let redactor = NetworkRedactor(config: .init())
    
    private func redact(body: String, contentType: String, redactor: NetworkRedactor? = nil) -> (NetworkLog.Body?, Int) {
        var count = 0
        let data = Data(body.utf8)
        let result = (redactor ?? self.redactor).redact(body: data, totalBytes: data.count, contentType: contentType, count: &count)
        return (result, count)
    }
    
    func testAlwaysRedactedHeaders() {
        var count = 0
        let headers = redactor.redact(headers: [.init(name: "Authorization", value: "Bearer x"),
                                                .init(name: "cookie", value: "a=b"),
                                                .init(name: "Set-Cookie", value: "c=d"),
                                                .init(name: "Proxy-Authorization", value: "Basic y"),
                                                .init(name: "Accept", value: "*/*")],
                                      count: &count)
        
        XCTAssertEqual(headers.map(\.name), ["Authorization", "cookie", "Set-Cookie", "Proxy-Authorization", "Accept"])
        XCTAssertEqual(headers.map(\.value), ["[REDACTED]", "[REDACTED]", "[REDACTED]", "[REDACTED]", "*/*"])
        XCTAssertEqual(count, 4)
    }
    
    func testConfiguredHeaders() {
        var count = 0
        let redactor = NetworkRedactor(config: .init(redactHeaders: ["X-Api-Key"]))
        let headers = redactor.redact(headers: [.init(name: "x-api-key", value: "123")], count: &count)
        XCTAssertEqual(headers, [.init(name: "x-api-key", value: "[REDACTED]")])
    }
    
    func testJSONFieldsAtAnyDepth() throws {
        let (body, count) = redact(body: #"{"user":{"password":"p","name":"n","items":[{"access_token":"t","id":1}]}}"#, contentType: "application/json; charset=utf-8")
        
        XCTAssertEqual(body?.text, #"{"user":{"password":"[REDACTED]","name":"n","items":[{"access_token":"[REDACTED]","id":1}]}}"#)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(body?.truncated, false)
    }
    
    func testJSONKeepsOrderNumbersAndFormatting() {
        let (body, count) = redact(body: "{\n  \"b\": 1.50,\n  \"token\": \"t\",\n  \"a\": 10000000000000000001\n}", contentType: "application/json")
        
        XCTAssertEqual(body?.text, "{\n  \"b\": 1.50,\n  \"token\": \"[REDACTED]\",\n  \"a\": 10000000000000000001\n}")
        XCTAssertEqual(count, 1)
    }
    
    func testTextBodiesAreRedacted() {
        let cases: [(body: String, contentType: String, expected: String)] = [
            (#"{"password":"p","name":"n"}"#, "text/plain", #"{"password":"[REDACTED]","name":"n"}"#),
            (#"<s:Envelope><ns:Password>p</ns:Password><user name="a" token='t'/></s:Envelope>"#, "application/soap+xml",
             #"<s:Envelope><ns:Password>[REDACTED]</ns:Password><user name="a" token='[REDACTED]'/></s:Envelope>"#),
            (#"{"query":"mutation { login }","variables":{"password":"p"}}"#, "application/graphql", #"{"query":"mutation { login }","variables":{"password":"[REDACTED]"}}"#),
            ("user=a&password=p", "text/plain", "user=a&password=[REDACTED]"),
            ("Authorization: Bearer abc.def", "text/plain", "Authorization: Bearer [REDACTED]"),
        ]
        for (text, contentType, expected) in cases {
            let (body, count) = redact(body: text, contentType: contentType)
            XCTAssertEqual(body?.text, expected, contentType)
            XCTAssertGreaterThan(count, 0, contentType)
        }
    }
    
    /// A long token without a separator, such as Base64, must not make the patterns backtrack: four times the input
    /// may take about four times as long, not sixteen. Compared, not timed, because CI runners are slow.
    func testLongTokensAreRedactedInLinearTime() {
        func fastest(_ length: Int) -> TimeInterval {
            let token = String(repeating: "aB3_", count: length / 4)
            let texts = [token, "<" + token, token + "=", "x " + token + " y=\"", "\"" + token, token + ":" + token]
            return (0..<3).map { _ in
                let start = Date()
                texts.forEach { _ = redact(body: $0, contentType: "text/plain") }
                return Date().timeIntervalSince(start)
            }.min()!
        }
        let short = fastest(64 * 1024)
        let long = fastest(256 * 1024)
        XCTAssertLessThan(long / short, 10, "64 KB: \(short) s, 256 KB: \(long) s")
    }
    
    func testJSONFieldNamesIgnoreCaseAndSeparators() {
        let (body, count) = redact(body: #"{"Client-Secret":1,"ID_TOKEN":null,"refreshtoken":[1,2]}"#, contentType: "application/vnd.api+json")
        XCTAssertEqual(body?.text, #"{"Client-Secret":"[REDACTED]","ID_TOKEN":"[REDACTED]","refreshtoken":"[REDACTED]"}"#)
        XCTAssertEqual(count, 3)
    }
    
    func testDefaultFieldsInJSONAndQuery() {
        let keys = ["password", "secret", "token", "access_token", "refresh-token", "ID_TOKEN", "credential", "api_key", "clientSecret"]
        let json = "{" + keys.map { "\"\($0)\":\"v\"" }.joined(separator: ",") + #","tokenType":"Bearer"}"#
        let (body, bodyCount) = redact(body: json, contentType: "application/json")
        XCTAssertEqual(bodyCount, keys.count)
        XCTAssertTrue(body?.text.contains(#""tokenType":"Bearer""#) == true)
        
        var queryCount = 0
        let url = redactor.redact(url: "https://api.example.com/?" + keys.map { "\($0)=v" }.joined(separator: "&") + "&page=2", count: &queryCount)
        XCTAssertEqual(queryCount, keys.count)
        XCTAssertTrue(url.hasSuffix("&page=2"))
        XCTAssertFalse(url.contains("=v"))
    }
    
    func testFormBody() {
        let (body, count) = redact(body: "user=a&password=p%20w&access_token=t", contentType: "application/x-www-form-urlencoded")
        XCTAssertEqual(body?.text, "user=a&password=[REDACTED]&access_token=[REDACTED]")
        XCTAssertEqual(count, 2)
    }
    
    func testQueryParamsAndUserInfo() {
        var count = 0
        let url = redactor.redact(url: "https://user:pass@api.example.com/v1/items?page=2&token=abc&API_KEY=k#top", count: &count)
        XCTAssertEqual(url, "https://[REDACTED]@api.example.com/v1/items?page=2&token=[REDACTED]&API_KEY=[REDACTED]#top")
        XCTAssertEqual(count, 3)
    }
    
    func testURLWithoutSecretsIsUnchanged() {
        var count = 0
        XCTAssertEqual(redactor.redact(url: "https://api.example.com/v1/items?page=2", count: &count), "https://api.example.com/v1/items?page=2")
        XCTAssertEqual(count, 0)
    }
    
    func testLargeJSONIsRedactedBeforeTruncation() throws {
        let prefix = #"{"accessToken":"secret","data":""#
        let suffix = #""}"#
        let json = prefix + String(repeating: "x", count: 307_200 - prefix.utf8.count - suffix.utf8.count) + suffix
        XCTAssertEqual(json.utf8.count, 307_200)
        
        let (body, count) = redact(body: json, contentType: "application/json")
        
        let stored = try XCTUnwrap(body)
        XCTAssertEqual(stored.text.utf8.count, 256 * 1024)
        XCTAssertTrue(stored.truncated)
        XCTAssertEqual(stored.originalBytes, 307_200)
        XCTAssertTrue(stored.text.hasPrefix(#"{"accessToken":"[REDACTED]","data":"xxx"#))
        XCTAssertFalse(stored.text.contains("secret"))
        XCTAssertEqual(count, 1)
    }
    
    func testTruncationKeepsMultiByteCharactersWhole() throws {
        let redactor = NetworkRedactor(config: .init(maxBodyBytes: 5))
        let (body, _) = redact(body: "abcdé", contentType: "text/plain", redactor: redactor)
        XCTAssertEqual(body?.text, "abcd")
        XCTAssertEqual(body?.truncated, true)
        XCTAssertEqual(body?.originalBytes, 6)
    }
    
    func testJSONTooLargeToRedact() {
        var count = 0
        let size = NetworkRedactor.maxRedactableBytes + 1
        let body = redactor.redact(body: Data(count: NetworkRedactor.maxRedactableBytes), totalBytes: size, contentType: "application/json", count: &count)
        XCTAssertEqual(body?.text, "(\(size) bytes, too large to redact)")
        XCTAssertEqual(body?.isText, false)
    }
    
    func testUnparsableJSON() {
        let (body, _) = redact(body: #"{"password": "#, contentType: "application/json")
        XCTAssertEqual(body?.text, "(unparsable JSON, not shown)")
        XCTAssertEqual(body?.isText, false)
    }
    
    func testBinaryAndEmptyBodies() {
        XCTAssertEqual(redact(body: "PNG...", contentType: "image/png").0?.text, "(binary, 6 bytes)")
        XCTAssertNil(redact(body: "", contentType: "application/json").0)
    }
    
    func testMultipart() {
        let body = [
            "--B",
            #"Content-Disposition: form-data; name="title""#,
            "",
            "Hello",
            "--B",
            #"Content-Disposition: form-data; name="password""#,
            "",
            "p",
            "--B",
            #"Content-Disposition: form-data; name="file"; filename="a.png""#,
            "Content-Type: image/png",
            "",
            "12345",
            "--B--",
            "",
        ].joined(separator: "\r\n")
        
        let (result, count) = redact(body: body, contentType: "multipart/form-data; boundary=B")
        
        XCTAssertEqual(result?.text, [
            "--B",
            #"Content-Disposition: form-data; name="title""#,
            "",
            "Hello",
            "--B",
            #"Content-Disposition: form-data; name="password""#,
            "",
            "[REDACTED]",
            "--B",
            #"Content-Disposition: form-data; name="file"; filename="a.png""#,
            "Content-Type: image/png",
            "",
            "(file a.png, 5 bytes)",
            "--B--",
        ].joined(separator: "\r\n"))
        XCTAssertEqual(count, 1)
    }
}
