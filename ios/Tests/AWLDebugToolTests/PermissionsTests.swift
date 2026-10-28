import XCTest
@testable import AWLDebugTool

@objc(AWLFakeAuthorizationManager)
final class FakeAuthorizationManager: NSObject {
    @objc class func authorizationStatus() -> Int { 3 }
    @objc class func narrowStatus() -> Int32 { 4 }
    @objc class func statusForLevel(_ level: Int) -> Int { level * 2 }
    @objc class func statusForType(_ type: NSString) -> Int { type == "vide" ? 1 : 0 }
}

@MainActor
final class PermissionsTests: XCTestCase {

    func testClassMethodsAreCalledThroughTheRuntime() {
        XCTAssertEqual(ObjCStatus.int(className: "AWLFakeAuthorizationManager", selector: "authorizationStatus"), 3)
        XCTAssertEqual(ObjCStatus.int32(className: "AWLFakeAuthorizationManager", selector: "narrowStatus"), 4)
        XCTAssertEqual(ObjCStatus.int(className: "AWLFakeAuthorizationManager", selector: "statusForLevel:", integer: 2), 4)
        XCTAssertEqual(ObjCStatus.int(className: "AWLFakeAuthorizationManager", selector: "statusForType:", object: "vide" as NSString), 1)
    }

    func testMissingClassOrSelectorGivesNoStatus() {
        XCTAssertNil(ObjCStatus.int(className: "AWLNotLoadedClass", selector: "authorizationStatus"))
        XCTAssertNil(ObjCStatus.int(className: "AWLFakeAuthorizationManager", selector: "missingSelector"))
    }

    func testCameraStatusIsReadFromTheLoadedFramework() {
        // AVFoundation is loaded in this process, so the real class method answers.
        XCTAssertNotEqual(PermissionsManager.runtimeStatus(for: .cameraAccess), .unknown)
    }

    func testOnlyDeclaredPermissionsAreListed() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let plist: [String: Any] = ["CFBundleIdentifier": "com.example.permissions",
                                    "NSCameraUsageDescription": "Scan codes",
                                    "NSLocationAlwaysAndWhenInUseUsageDescription": "Track rides"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: url.appendingPathComponent("Info.plist"))

        let bundle = try XCTUnwrap(Bundle(url: url))
        XCTAssertEqual(PermissionsManager(bundle: bundle).declaredTypes, [.locationAccess, .cameraAccess, .notificationsAccess])
    }
}
