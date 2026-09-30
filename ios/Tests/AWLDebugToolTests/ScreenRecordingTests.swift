import SwiftUI
import XCTest
@testable import AWLDebugTool

@MainActor
final class ScreenRecordingTests: XCTestCase {

    // AK-REC-1, AK-REC-2: secure fields and marked views are black in the stored frame.
    func testSecureFieldsAndMarkedViewsAreBlackInTheEncodedFrame() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        let root = UIViewController()
        root.view.backgroundColor = .white
        window.rootViewController = root

        let secureField = UITextField(frame: CGRect(x: 20, y: 20, width: 200, height: 40))
        secureField.isSecureTextEntry = true
        secureField.text = "hunter2"
        secureField.backgroundColor = .yellow
        root.view.addSubview(secureField)

        let marked = UIView(frame: CGRect(x: 20, y: 80, width: 100, height: 40))
        marked.backgroundColor = .red
        marked.awlDebugMasked = true
        root.view.addSubview(marked)

        let host = UIHostingController(rootView: VStack(spacing: 0) {
            SecureField("Password", text: .constant("hunter2")).frame(height: 40)
            Color.blue.frame(height: 40).awlDebugMasked()
            Color.green.frame(height: 40)
        }.frame(width: 200))
        host.view.frame = CGRect(x: 20, y: 140, width: 200, height: 120)
        root.addChild(host)
        root.view.addSubview(host.view)
        window.isHidden = false
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()

        let captured = try XCTUnwrap(RecordingFrameRenderer.capture(windows: [window], bounds: window.bounds))
        // A window outside a scene draws nothing in a test, so the masks go onto a white picture of the same size.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let white = UIGraphicsImageRenderer(size: captured.image.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: captured.image.size))
        }
        let frame = RecordingFrame(image: white, masks: captured.masks, date: captured.date)
        let jpeg = try XCTUnwrap(RecordingFrameRenderer.encode(frame, touches: []))
        let image = try XCTUnwrap(UIImage(data: jpeg)?.cgImage)

        XCTAssertEqual(frame.masks.count, 4, "\(frame.masks)")
        for rect in frame.masks {
            for point in [CGPoint(x: rect.midX, y: rect.midY), CGPoint(x: rect.minX + 3, y: rect.minY + 3),
                          CGPoint(x: rect.maxX - 3, y: rect.maxY - 3)] {
                XCTAssertTrue(isBlack(image, at: point), "not black at \(point) in \(rect)")
            }
        }
        XCTAssertFalse(isBlack(image, at: CGPoint(x: 250, y: 380)))
    }

    // AK-REC-7: a sheet over a masked screen is recorded without the masks of the screen below.
    func testOpaqueViewOnTopHidesMasksBelowIt() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        let secureField = UITextField(frame: CGRect(x: 20, y: 20, width: 200, height: 40))
        secureField.isSecureTextEntry = true
        window.addSubview(secureField)
        window.isHidden = false
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window)?.count, 1)

        let cover = UIView(frame: CGRect(x: 0, y: 10, width: 300, height: 390))
        cover.backgroundColor = .white
        window.addSubview(cover)
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window), [])

        cover.backgroundColor = .white.withAlphaComponent(0.5)
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window)?.count, 1, "a see-through view keeps the mask")
    }

    // AK-REC-1: an opaque view only hides a mask where it is really drawn.
    func testClippedOrSeeThroughViewsKeepTheMask() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        let secureField = UITextField(frame: CGRect(x: 20, y: 20, width: 200, height: 40))
        secureField.isSecureTextEntry = true
        window.addSubview(secureField)
        window.isHidden = false

        // A row scrolled out of its list: its frame covers the field, but the list clips it away.
        let list = UIView(frame: CGRect(x: 0, y: 100, width: 300, height: 300))
        list.clipsToBounds = true
        let row = UIView(frame: CGRect(x: 0, y: -100, width: 300, height: 200))
        row.backgroundColor = .white
        list.addSubview(row)
        window.addSubview(list)
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window)?.count, 1, "clipped view")
        list.removeFromSuperview()

        // An opaque view inside a half transparent one lets the field shine through.
        let faded = UIView(frame: window.bounds)
        faded.alpha = 0.5
        let cover = UIView(frame: window.bounds)
        cover.backgroundColor = .white
        faded.addSubview(cover)
        window.addSubview(faded)
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window)?.count, 1, "see-through parent")

        // Rounded corners of a sheet do not cover what is below them.
        faded.alpha = 1
        cover.frame = CGRect(x: 10, y: 10, width: 280, height: 380)
        cover.layer.cornerRadius = 20
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window)?.count, 1, "rounded corner")
        cover.layer.cornerRadius = 0
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window), [], "opaque cover")
    }

    // AK-REC-1: while views animate, drawHierarchy draws them between start and end, so a moving view covers
    // nothing and a moving masked view skips the frame.
    func testMovingViewsNeitherCoverMasksNorGetMasked() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        let root = UIViewController()
        window.rootViewController = root
        let secureField = UITextField(frame: CGRect(x: 20, y: 20, width: 200, height: 40))
        secureField.isSecureTextEntry = true
        root.view.addSubview(secureField)
        // A sheet with its own secure field that slides in from below.
        let sheet = UIView(frame: CGRect(x: 0, y: 400, width: 300, height: 400))
        sheet.backgroundColor = .white
        root.view.addSubview(sheet)
        window.isHidden = false
        window.layoutIfNeeded()
        CATransaction.flush()
        defer { sheet.layer.removeAllAnimations() }

        UIView.animate(withDuration: 60, delay: 0, options: .curveLinear) {
            sheet.frame.origin.y = 0
        }
        CATransaction.flush()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(RecordingFrameRenderer.maskedRects(in: window), [CGRect(x: 20, y: 20, width: 200, height: 40)],
                       "the sliding sheet has not reached the field yet")

        let sheetField = UITextField(frame: CGRect(x: 20, y: 100, width: 200, height: 40))
        sheetField.isSecureTextEntry = true
        sheet.addSubview(sheetField)
        XCTAssertNil(RecordingFrameRenderer.maskedRects(in: window), "the sheet's field is somewhere on its way")
        XCTAssertNil(RecordingFrameRenderer.capture(windows: [window], bounds: window.bounds))
    }

    // AK-REC-3: no frames without activity.
    func testNoFramesWithoutActivity() {
        var activity = RecordingActivity()
        let start = Date()
        activity.noteActivity(at: start)
        let ticks = (1...180).map { start.addingTimeInterval(Double($0) / 3) }
        let captured = ticks.filter { activity.shouldCapture(at: $0, isTouching: false) }
        // Two ticks inside the active second, then two trailing frames, then nothing for the remaining minute.
        XCTAssertEqual(captured.count, 4)
        XCTAssertLessThan(captured.last!.timeIntervalSince(start), 2)

        XCTAssertTrue(activity.shouldCapture(at: start.addingTimeInterval(61), isTouching: true))
    }

    // AK-REC-5: after a crash the frames of the previous run are the last recording.
    func testRotationKeepsThePreviousRunAsLastRecording() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "recording-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let crashedRun = RecordingStorage(root: root)
        crashedRun.rotate()
        let firstFrame = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0 ..< 10 {
            crashedRun.write(Data("frame \(index)".utf8), capturedAt: firstFrame.addingTimeInterval(Double(index)), maxFrames: 4)
        }
        XCTAssertEqual(RecordingStorage.frames(in: crashedRun.currentFolder).count, 4, "ring buffer keeps the newest frames")

        let nextRun = RecordingStorage(root: root)
        nextRun.rotate()
        let last = RecordingStorage.frames(in: nextRun.lastFolder)
        XCTAssertEqual(try last.map { try String(contentsOf: $0) }, ["frame 6", "frame 7", "frame 8", "frame 9"])
        XCTAssertEqual(RecordingStorage.newestFrameDate(in: nextRun.lastFolder), firstFrame.addingTimeInterval(9))
        XCTAssertTrue(RecordingStorage.frames(in: nextRun.currentFolder).isEmpty)
    }

    // AK-REC-7: the SDK's own windows and the keyboard are never recorded.
    func testSDKWindowsAreNotRecorded() {
        let appWindow = UIWindow(frame: .zero)
        let sdkWindow = UIWindow(frame: .zero)
        sdkWindow.accessibilityIdentifier = RecordingFrameRenderer.sdkWindowIdentifier
        XCTAssertTrue(RecordingFrameRenderer.isAppWindow(appWindow))
        XCTAssertFalse(RecordingFrameRenderer.isAppWindow(sdkWindow))
    }

    func testConfigDurationIsRoundedToAPanelOption() {
        XCTAssertEqual(Constants.MaxScreenVideoDuration.closest(toSeconds: 300), .fiveMinutes)
        XCTAssertEqual(Constants.MaxScreenVideoDuration.closest(toSeconds: 45), .halfMinute)
        XCTAssertEqual(Constants.MaxScreenVideoDuration.closest(toSeconds: 3_600), .tenMinutes)
    }

    private func isBlack(_ image: CGImage, at point: CGPoint) -> Bool {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: -point.x, y: point.y - CGFloat(image.height) + 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixel[0] < 30 && pixel[1] < 30 && pixel[2] < 30
    }
}
