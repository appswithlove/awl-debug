import XCTest
@testable import AWLDebugTool

@MainActor
final class VersionOverlayTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKey.versionOverlayVisible)
        super.tearDown()
    }

    func testTextShowsVersionAndBuild() {
        XCTAssertNotNil(VersionOverlayPresenter.text.range(of: #"^AWL \S* \(\S*\)$"#, options: .regularExpression), VersionOverlayPresenter.text)
    }

    func testOverlayIsOnByDefaultAndTheSwitchIsStored() {
        XCTAssertTrue(VersionOverlayPresenter.isEnabled)
        UserDefaults.standard.set(false, forKey: Constants.UserDefaultsKey.versionOverlayVisible)
        XCTAssertFalse(VersionOverlayPresenter.isEnabled)
    }
}
