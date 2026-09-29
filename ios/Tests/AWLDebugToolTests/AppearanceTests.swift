import XCTest
@testable import AWLDebugTool

final class AppearanceTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: DebugView.Keys.preferredColorScheme)
        super.tearDown()
    }

    func testSchemesMapToWindowStyles() {
        XCTAssertEqual(DebugView.AppColorScheme.auto.userInterfaceStyle, .unspecified)
        XCTAssertEqual(DebugView.AppColorScheme.light.userInterfaceStyle, .light)
        XCTAssertEqual(DebugView.AppColorScheme.dark.userInterfaceStyle, .dark)
        XCTAssertEqual(DebugView.AppColorScheme.allCases.map(\.ls), ["System", "Light", "Dark"])
    }

    func testStoredSchemeSurvivesRelaunch() {
        XCTAssertEqual(DebugView.AppColorScheme.stored, .auto)
        UserDefaults.standard.set(DebugView.AppColorScheme.dark.rawValue, forKey: DebugView.Keys.preferredColorScheme)
        XCTAssertEqual(DebugView.AppColorScheme.stored, .dark)
    }
}
