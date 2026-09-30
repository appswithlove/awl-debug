import Security
import XCTest
@testable import AWLDebugTool

final class AppDataCleanerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "AppDataCleanerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private var cleaner: AppDataCleaner {
        AppDataCleaner(defaults: defaults, domainName: suiteName, directories: [directory])
    }

    func testUserDefaultsAreClearedButToolSettingsKept() {
        defaults.set("user-42", forKey: "userId")
        defaults.set(true, forKey: "onboardingDone")
        defaults.set(250, forKey: "AWLDebugTool_networkLogsLimit")
        defaults.set("dark", forKey: "DebugView.userPreferredColorScheme")

        cleaner.clear([.userDefaults])

        XCTAssertNil(defaults.object(forKey: "userId"))
        XCTAssertNil(defaults.object(forKey: "onboardingDone"))
        XCTAssertEqual(defaults.integer(forKey: "AWLDebugTool_networkLogsLimit"), 250)
        XCTAssertEqual(defaults.string(forKey: "DebugView.userPreferredColorScheme"), "dark")
    }

    func testFilesAreDeletedButToolFoldersKept() throws {
        let fileManager = FileManager.default
        try Data("x".utf8).write(to: directory.appendingPathComponent("cache.json"))
        try fileManager.createDirectory(at: directory.appendingPathComponent("Downloads"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: directory.appendingPathComponent("AWLDebugTool"), withIntermediateDirectories: true)

        cleaner.clear([.files])

        let remaining = try fileManager.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(remaining, ["AWLDebugTool"])
    }

    func testOnlySelectedAreasAreCleared() throws {
        defaults.set("user-42", forKey: "userId")
        try Data("x".utf8).write(to: directory.appendingPathComponent("cache.json"))

        cleaner.clear([.files])

        XCTAssertEqual(defaults.string(forKey: "userId"), "user-42")
    }

    func testCookiesAreCleared() throws {
        let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "example.com", .path: "/", .name: "session", .value: "abc"]))
        HTTPCookieStorage.shared.setCookie(cookie)

        cleaner.clear([.cookies])

        XCTAssertTrue(HTTPCookieStorage.shared.cookies(for: URL(string: "https://example.com")!)?.isEmpty ?? true)
    }

    func testKeychainItemsAreDeleted() throws {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: "test-\(UUID().uuidString)",
                                      kSecValueData: Data("secret".utf8)]
        let added = SecItemAdd(query as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw XCTSkip("The test runner has no keychain access group (OSStatus \(added)); checked in the example app instead.")
        }

        cleaner.clear([.keychain])

        var result: AnyObject?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrAccount: query[kSecAttrAccount]!] as CFDictionary, &result)
        XCTAssertEqual(status, errSecItemNotFound)
    }
}
