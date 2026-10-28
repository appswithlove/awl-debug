import OSLog
import XCTest
@testable import AWLDebugTool

@MainActor
final class AppLogsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppLogsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func entry(_ message: String, level: AWLDebugLogLevel = .info, tag: String? = nil, error: String? = nil,
                       offset: TimeInterval = 0) -> AppLogEntry {
        AppLogEntry(date: Date(timeIntervalSince1970: 1_790_000_000 + offset), level: level, tag: tag, message: message, errorDescription: error)
    }

    func testCredentialsAreRedacted() {
        XCTAssertEqual("Authorization: Bearer abc.def".redactingCredentials(), "Authorization: Bearer [REDACTED]")
        XCTAssertEqual("auth basic dXNlcjpwYXNz ok".redactingCredentials(), "auth basic [REDACTED] ok")
        XCTAssertEqual("Basic setup done".redactingCredentials(), "Basic setup done")
    }

    /// Same cases as the Android `CredentialRedactionTest`.
    func testJsonFieldsAreRedacted() {
        XCTAssertEqual(#"Body: {"user":"max","password":"hunter2","auth":{"access_token":"a.b","expires":3600}}"#.redactingSecrets(),
                       #"Body: {"user":"max","password":"[REDACTED]","auth":{"access_token":"[REDACTED]","expires":3600}}"#)
        XCTAssertEqual(#"{"apiKey": 12345, "Credential": {"id": 1, "pin": "0000"}, "token": null, "ok": true}"#.redactingSecrets(),
                       #"{"apiKey": "[REDACTED]", "Credential": "[REDACTED]", "token": "[REDACTED]", "ok": true}"#)
        XCTAssertEqual(#"payload="{\"refreshToken\":\"r1\",\"name\":\"x\"}""#.redactingSecrets(),
                       #"payload="{\"refreshToken\":\"[REDACTED]\",\"name\":\"x\"}""#)
        XCTAssertEqual(#"{"clientSecret":"abc"#.redactingSecrets(), #"{"clientSecret":"[REDACTED]""#)
        XCTAssertEqual(#"token rotation done, {"tokenType":"Bearer-less","secretary":"Ann"}"#.redactingSecrets(),
                       #"token rotation done, {"tokenType":"Bearer-less","secretary":"Ann"}"#)
        XCTAssertEqual(#"Grüße {"password":"päss\"wörd","note":"ok"} 👍"#.redactingSecrets(),
                       #"Grüße {"password":"[REDACTED]","note":"ok"} 👍"#)
    }

    func testOSLogLevelsMapToSeverities() {
        XCTAssertEqual(OSLogReader.level(of: .debug), .debug)
        XCTAssertEqual(OSLogReader.level(of: .info), .info)
        XCTAssertEqual(OSLogReader.level(of: .notice), .info)
        XCTAssertEqual(OSLogReader.level(of: .error), .error)
        XCTAssertEqual(OSLogReader.level(of: .fault), .error)
    }

    func testAppLoggerEntriesAreReadFromTheUnifiedLog() throws {
        let subsystem = "awl-debug-tests-\(UUID().uuidString)"
        Logger(subsystem: subsystem, category: "Auth").error("failed with Bearer secret-token")
        let reader = OSLogReader(subsystems: [subsystem])

        var entries: [AppLogEntry] = []
        for _ in 0..<30 where entries.isEmpty {
            entries = try reader.entries(after: nil).entries
            if entries.isEmpty {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.tag, "\(subsystem)/Auth")
        XCTAssertEqual(entry.message, "failed with Bearer [REDACTED]")
    }

    func testAppleSubsystemsAreLeftOutByDefault() {
        let reader = OSLogReader(subsystems: nil)
        XCTAssertFalse(reader.isIncluded(subsystem: "com.apple.UIKit"))
        XCTAssertTrue(reader.isIncluded(subsystem: "com.example.app"))
        XCTAssertTrue(reader.isIncluded(subsystem: ""))
    }

    func testFiltersApplyToListAndExport() {
        let store = AppLogsStore(defaults: defaults)
        store.append(entry("started", level: .info, tag: "App"))
        store.append(entry("failed", level: .error, tag: "Auth", error: "AuthError: expired\nline 2", offset: 1))
        store.append(entry("retry failed", level: .warn, tag: "Net", offset: 2))

        store.selectedLevels = [.error]
        XCTAssertEqual(store.filteredEntries.map(\.message), ["failed"])

        let lines = store.exportText(appInfo: "Example 1.0 (1)").components(separatedBy: "\n")
        XCTAssertEqual(Array(lines.prefix(4)), ["Example 1.0 (1)", "Levels: ERROR", "Search: -", ""])
        XCTAssertEqual(lines.count, 7)
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000(Z|[+-]\d{2}:\d{2}) \| ERROR \| Auth \| failed$"#
        XCTAssertNotNil(lines[4].range(of: pattern, options: .regularExpression), lines[4])
        XCTAssertEqual(Array(lines.suffix(2)), ["    AuthError: expired", "    line 2"])

        store.selectedLevels = []
        store.searchText = "NET"
        XCTAssertEqual(store.filteredEntries.map(\.message), ["retry failed"])
    }

    func testLimitKeepsNewestAndIsStored() {
        let store = AppLogsStore(defaults: defaults)
        store.limit = 10
        for index in 0..<15 {
            store.append(entry("\(index)", offset: TimeInterval(index)))
        }

        XCTAssertEqual(store.entries.map(\.message), (5..<15).map { "\($0)" })
        XCTAssertEqual(AppLogsStore(defaults: defaults).limit, 10)
    }

    func testEntriesAreDroppedWhileNotRecording() {
        let store = AppLogsStore(defaults: defaults)
        store.isRecording = false
        store.append(entry("dropped"))

        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(AppLogsStore(defaults: defaults).isRecording)
    }

    func testClearHidesEarlierEntries() {
        let store = AppLogsStore(defaults: defaults)
        store.append(entry("old"))
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
    }
}
