import Combine
import UIKit
import XCTest
@testable import AWLDebugTool

final class ExtensionsTests: XCTestCase {

    private var server: LocalHTTPServer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        server = try LocalHTTPServer()
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }

    // MARK: - Sections

    @MainActor
    private var testSectionIds: [String] {
        ExtensionSectionRegistry.shared.sections.map(\.id).filter { $0.hasPrefix("test-") }
    }

    @MainActor
    func testSectionsSortByOrderThenRegistrationAndUpdate() {
        let late = AWLDebugExtensionSection(id: "test-late", order: 20, items: [.text("late")])
        let first = AWLDebugExtensionSection(id: "test-first", order: 10, items: [.text("first")])
        let second = AWLDebugExtensionSection(id: "test-second", order: 10)
        let registrations = [late, first, second].map { AWLDebugExtensions.register($0) }
        defer { registrations.forEach { $0.cancel() } }

        XCTAssertEqual(testSectionIds, ["test-first", "test-second", "test-late"])

        var changes = 0
        let observer = second.objectWillChange.sink { changes += 1 }
        second.items = [.title("Second", action: AWLDebugExtensionAction("Run") {})]
        second.claimedTriggers = [.shake]
        XCTAssertEqual(changes, 2)
        observer.cancel()

        // The same id replaces the section; cancelling the old registration keeps the new one.
        let replacement = AWLDebugExtensionSection(id: "test-first", order: 30)
        let replacementRegistration = AWLDebugExtensions.register(replacement)
        XCTAssertEqual(testSectionIds, ["test-second", "test-late", "test-first"])
        registrations[1].cancel()
        XCTAssertTrue(ExtensionSectionRegistry.shared.sections.contains { $0 === replacement })

        replacementRegistration.cancel()
        registrations[0].cancel()
        registrations[0].cancel()
        XCTAssertEqual(testSectionIds, ["test-second"])
    }

    @MainActor
    func testCancelOffTheMainThreadRemovesTheSection() async {
        let registration = AWLDebugExtensions.register(AWLDebugExtensionSection(id: "test-background"))
        await Task.detached { registration.cancel() }.value
        for _ in 0 ..< 50 where testSectionIds.contains("test-background") {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(testSectionIds.contains("test-background"))
    }

    @MainActor
    func testLinkClosesThePanelThenRuns() async {
        let steps = Locked<[String]>([])
        await ExtensionLink.open({ steps.append("action") }, closePanel: { steps.append("close") })
        XCTAssertEqual(steps.value, ["close", "action"])

        // With the real panel, closed here: the action still runs.
        await ExtensionLink.open { steps.append("real") }
        XCTAssertEqual(steps.value.last, "real")
        XCTAssertFalse(AWLDebugTool.isOpen)
    }

    @MainActor
    func testClaimedTriggersDoNotOpenThePanel() {
        let presenter = DebugPanelPresenter.shared
        let previous = (triggers: presenter.triggers, isAlwaysActive: presenter.isAlwaysActive)
        presenter.configure(triggers: [.screenshot, .tripleTap], isAlwaysActive: true)
        defer { presenter.configure(triggers: previous.triggers, isAlwaysActive: previous.isAlwaysActive) }
        XCTAssertTrue(presenter.opensPanel(on: .screenshot))

        let section = AWLDebugExtensionSection(id: "test-claims", claimedTriggers: [.screenshot])
        let registration = AWLDebugExtensions.register(section)
        defer { registration.cancel() }

        XCTAssertFalse(presenter.opensPanel(on: .screenshot))
        XCTAssertTrue(presenter.opensPanel(on: .tripleTap))
        XCTAssertFalse(presenter.opensPanel(on: .threeFingerTap), "not configured")

        section.claimedTriggers = []
        XCTAssertTrue(presenter.opensPanel(on: .screenshot))
    }

    // MARK: - Network

    private func load(_ request: URLRequest) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AWLDebugURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let loaded = expectation(description: request.url?.path ?? "")
        session.dataTask(with: request) { _, _, _ in loaded.fulfill() }.resume()
        wait(for: [loaded], timeout: 10)
    }

    func testObservedRequestsAreRedactedAndFailuresCarryAnErrorCode() throws {
        server.route("/observed", .init(headers: [("Content-Type", "text/plain"), ("Set-Cookie", "session=abc")]))
        let closed = try LocalHTTPServer()
        let refusedURL = closed.url("/refused")
        closed.stop()

        let records = Locked<[AWLDebugNetworkRecord]>([])
        let observed = expectation(description: "observed")
        observed.expectedFulfillmentCount = 2
        let registration = AWLDebugExtensions.observeNetwork { record in
            guard record.url.hasSuffix("/observed") || record.url.hasSuffix("/refused") else { return }
            records.append(record)
            observed.fulfill()
        }
        defer { registration.cancel() }

        var request = URLRequest(url: server.url("/observed"))
        request.setValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        load(request)
        load(URLRequest(url: refusedURL))
        wait(for: [observed], timeout: 10)

        let succeeded = try XCTUnwrap(records.value.first { $0.url.hasSuffix("/observed") })
        XCTAssertEqual(succeeded.method, "GET")
        XCTAssertEqual(succeeded.statusCode, 200)
        XCTAssertNil(succeeded.errorCode)
        XCTAssertEqual(succeeded.requestHeaders.first { $0.name == "Authorization" }?.value, "[REDACTED]")
        XCTAssertEqual(succeeded.responseHeaders.first { $0.name.lowercased() == "set-cookie" }?.value, "[REDACTED]")
        XCTAssertEqual(succeeded.responseBody?.text, "ok")
        XCTAssertEqual(succeeded.responseBody?.isContent, true)
        XCTAssertEqual(succeeded.responseBytes, 2)

        let failed = try XCTUnwrap(records.value.first { $0.url.hasSuffix("/refused") })
        XCTAssertNil(failed.statusCode)
        XCTAssertEqual(failed.errorCode, "connection")

        // The Network module's list has both, ordered by start time.
        let expectedURLs = [request.url?.absoluteString, refusedURL.absoluteString]
        let logged = expectation(description: "logged")
        func poll() {
            let urls = AWLDebugExtensions.networkSnapshot(maxEntries: 50).map(\.url).filter(expectedURLs.contains)
            if urls == expectedURLs {
                logged.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            }
        }
        DispatchQueue.main.async(execute: poll)
        wait(for: [logged], timeout: 5)
        XCTAssertEqual(AWLDebugExtensions.networkSnapshot(maxEntries: 1).count, 1)
        XCTAssertEqual(AWLDebugExtensions.networkSnapshot(maxEntries: 0).count, 0)
    }

    func testExcludedRequestIsNotCaptured() throws {
        server.route("/excluded", .init())
        server.route("/captured", .init())
        let urls = Locked<[String]>([])
        let captured = expectation(description: "captured")
        let registration = AWLDebugExtensions.observeNetwork { record in
            guard record.url.hasSuffix("/excluded") || record.url.hasSuffix("/captured") else { return }
            urls.append(record.url)
            if record.url.hasSuffix("/captured") {
                captured.fulfill()
            }
        }
        defer { registration.cancel() }

        load(AWLDebugExtensions.excludeFromCapture(URLRequest(url: server.url("/excluded"))))
        load(URLRequest(url: server.url("/captured")))
        wait(for: [captured], timeout: 10)

        XCTAssertEqual(server.hitCount("/excluded"), 1)
        XCTAssertEqual(urls.value, [server.url("/captured").absoluteString])
    }

    // MARK: - Logs

    @MainActor
    func testLogSnapshotHonoursLevelAndSearchFilter() async throws {
        ExtensionState.shared.markStarted()
        let store = AWLDebugTool.shared.appLogs
        let previous = (levels: store.selectedLevels, search: store.searchText, config: store.config, isRecording: store.isRecording)
        defer {
            store.selectedLevels = previous.levels
            store.searchText = previous.search
            store.config = previous.config
            store.isRecording = previous.isRecording
        }
        store.config.readOSLog = false
        store.isRecording = true
        let marker = UUID().uuidString
        let now = Date()
        store.append(AppLogEntry(date: now, level: .info, tag: "Test", message: "\(marker) info", errorDescription: nil))
        store.append(AppLogEntry(date: now.addingTimeInterval(0.001), level: .warn, tag: "Test", message: "\(marker) warn", errorDescription: nil))
        store.append(AppLogEntry(date: now.addingTimeInterval(0.002), level: .error, tag: nil, message: "\(marker) error",
                                 errorDescription: "URLError: timed out"))
        store.append(AppLogEntry(date: now.addingTimeInterval(0.003), level: .error, tag: "Test", message: "other error", errorDescription: nil))
        store.selectedLevels = [.warn, .error]
        store.searchText = marker

        let newest = await AWLDebugExtensions.logSnapshot(maxEntries: 1)
        XCTAssertEqual(newest?.records.map(\.message), ["\(marker) error"])
        XCTAssertEqual(newest?.levelFilter, [.error, .warn])
        XCTAssertEqual(newest?.searchText, marker)

        let allSnapshot = await AWLDebugExtensions.logSnapshot(maxEntries: 500)
        let all = try XCTUnwrap(allSnapshot)
        XCTAssertEqual(all.records.map(\.message), ["\(marker) warn", "\(marker) error"])
        XCTAssertEqual(all.records.map(\.tag), ["Test", nil])
        XCTAssertEqual(all.records.last?.errorDescription, "URLError: timed out")
        XCTAssertEqual(all.records.last?.level, .error)

        store.selectedLevels = []
        store.searchText = ""
        let unfiltered = await AWLDebugExtensions.logSnapshot(maxEntries: 500)
        XCTAssertEqual(unfiltered?.levelFilter, [])
        XCTAssertEqual(unfiltered?.searchText, "")
        XCTAssertEqual(unfiltered?.records.filter { $0.message.hasPrefix(marker) }.count, 3)
    }

    // MARK: - Recording

    func testExportRecordingUsesTheRecordingOnDiskAndTheOptions() async throws {
        let storage = RecordingStorage()
        try? FileManager.default.removeItem(at: storage.currentFolder)
        defer { try? FileManager.default.removeItem(at: storage.currentFolder) }
        let hadLastRecording = RecordingStorage.newestFrameDate(in: storage.lastFolder) != nil
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let start = Date()
        for index in 0 ..< 6 {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 240), format: format).image { context in
                UIColor(hue: CGFloat(index) / 6, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 120, height: 240))
            }
            storage.write(try XCTUnwrap(image.jpegData(compressionQuality: 0.6)),
                          capturedAt: start.addingTimeInterval(Double(index) / 3), maxFrames: 100)
        }
        let wasRecordingOn = ExtensionState.shared.isRecordingOn
        defer { ExtensionState.shared.setRecordingOn(wasRecordingOn) }
        ExtensionState.shared.setRecordingOn(false)
        XCTAssertFalse(AWLDebugExtensions.hasRecording, "Frames left after switching recording off do not count")
        ExtensionState.shared.setRecordingOn(true)
        XCTAssertTrue(AWLDebugExtensions.hasRecording)

        let export = await AWLDebugExtensions.exportRecording(.init(lastSeconds: 1, maxTimelineBytes: 256 * 1024))
        let parts = try XCTUnwrap(export)
        XCTAssertNotNil(parts.video)
        XCTAssertNotNil(parts.frames)
        XCTAssertFalse(parts.isVideoTooLarge)
        let timeline = String(decoding: try XCTUnwrap(parts.timeline), as: UTF8.self)
        XCTAssertTrue(timeline.contains("frames: 3 · fps: 3"), timeline)

        let tooLarge = await AWLDebugExtensions.exportRecording(.init(maxVideoBytes: 10))
        XCTAssertEqual(tooLarge?.isVideoTooLarge, true)
        XCTAssertNil(tooLarge?.video)

        try FileManager.default.removeItem(at: storage.currentFolder)
        XCTAssertEqual(AWLDebugExtensions.hasRecording, hadLastRecording)
    }

    // MARK: - Clear App Data

    func testKeepOnClearAppDataKeepsTheKeys() throws {
        let suiteName = "ExtensionsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("Tester", forKey: "ExtensionTest.savedName")
        defaults.set("user-42", forKey: "userId")

        AWLDebugExtensions.keepOnClearAppData(userDefaultsPrefix: "ExtensionTest.")
        AWLDebugExtensions.keepOnClearAppData(userDefaultsPrefix: "")
        AppDataCleaner(defaults: defaults, domainName: suiteName, directories: []).clear([.userDefaults])

        XCTAssertEqual(defaults.string(forKey: "ExtensionTest.savedName"), "Tester")
        XCTAssertNil(defaults.object(forKey: "userId"))
    }
}

/// A value shared with callbacks on other threads.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func mutate(_ change: (inout Value) -> Void) {
        lock.lock()
        change(&stored)
        lock.unlock()
    }
}

extension Locked {
    func append<Element>(_ element: Element) where Value == [Element] {
        mutate { $0.append(element) }
    }
}
