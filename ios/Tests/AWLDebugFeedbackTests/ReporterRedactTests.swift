//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Foundation
import Testing
import UIKit

/// Sends real reports through the queue to an in-process endpoint and reads back what went over the wire.
@MainActor
@Suite(.serialized)
final class ReporterRedactTests {
    private let suiteName = "ReporterRedactTests-\(UUID().uuidString)"
    private let directory = FileManager.default.temporaryDirectory
        .appending(path: "ReporterRedactTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let defaults: UserDefaults
    private let runner: FeedbackQueueRunner

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CaptureProtocol.self]
        runner = FeedbackQueueRunner(queue: FeedbackQueue(directory: directory, session: URLSession(configuration: configuration)))
        CaptureProtocol.bodies = []
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeSession(reporter: FeedbackReporter? = nil) throws -> FeedbackSession {
        let config = try FeedbackConfig(
            endpoint: #require(URL(string: "https://feedback.example.com")),
            appKey: "key-123",
            appVersion: "1.0",
            buildNumber: "42",
            environment: "staging",
            reporter: reporter
        )
        return FeedbackSession(
            screenshot: Self.whiteImage(),
            config: config,
            queue: runner,
            logsSource: nil,
            reporterStore: ReporterStore(defaults: defaults)
        )
    }

    // AK-FB-3
    @Test
    func redactedAreaIsBlackInTheSentJPEG() async throws {
        let session = try makeSession(reporter: FeedbackReporter(name: "Tester"))
        session.tool = .redact
        session.color = .yellow
        session.dragMark(to: CGPoint(x: 0.2, y: 0.2))
        session.dragMark(to: CGPoint(x: 0.8, y: 0.5))
        session.endMark()
        session.text = "Password visible"

        await session.send()

        #expect(session.phase == .sent)
        let jpeg = try #require(Self.part(named: "screenshot", in: CaptureProtocol.bodies.last))
        let image = try #require(UIImage(data: jpeg))
        #expect(image.size == CGSize(width: 100, height: 200))
        for (x, y) in [(25, 45), (50, 70), (75, 95)] {
            let pixel = try Self.pixel(of: image, x: x, y: y)
            #expect(pixel.max() ?? 255 < 16, "(\(x), \(y)) is \(pixel)")
        }
        for (x, y) in [(10, 10), (50, 150), (90, 30)] {
            let pixel = try Self.pixel(of: image, x: x, y: y)
            #expect(pixel.min() ?? 0 > 240, "(\(x), \(y)) is \(pixel)")
        }
    }

    @Test
    func redactDragShorterThanASlipAddsNoMark() throws {
        let session = try makeSession()
        session.tool = .redact
        session.dragMark(to: CGPoint(x: 0.5, y: 0.5))
        session.dragMark(to: CGPoint(x: 0.505, y: 0.505))
        session.endMark()

        #expect(session.marks.isEmpty)
    }

    // AK-FB-5
    @Test
    func firstReportAsksForNameAndNextShowsSentAs() async throws {
        let first = try makeSession()
        #expect(first.isEditingReporter)
        first.text = "Button is cut off"
        #expect(!first.canSend)

        first.reporterName = " Tester 3 "
        first.reporterEmail = "tester@example.com"
        #expect(first.canSend)
        await first.send()

        #expect(first.phase == .sent)
        let metadata = try Self.metadata(in: CaptureProtocol.bodies.last)
        #expect(metadata["reporter"] as? [String: String] == ["name": "Tester 3", "email": "tester@example.com"])

        let second = try makeSession()
        #expect(!second.isEditingReporter)
        #expect(second.reporterName == "Tester 3")
        #expect(second.reporterEmail == "tester@example.com")
    }

    @Test
    func changedReporterIsSentAndSaved() async throws {
        ReporterStore(defaults: defaults).save(FeedbackReporter(name: "Tester", email: "tester@example.com"))
        let session = try makeSession()
        session.changeReporter()
        session.reporterName = "Tester 2"
        session.reporterEmail = ""
        session.text = "Wrong price"

        await session.send()

        let metadata = try Self.metadata(in: CaptureProtocol.bodies.last)
        #expect(metadata["reporter"] as? [String: String] == ["name": "Tester 2"])
        #expect(ReporterStore(defaults: defaults).load(fallback: nil) == FeedbackReporter(name: "Tester 2"))
    }

    @Test
    func configReporterPrefillsUntilTheTesterSavesOne() throws {
        let session = try makeSession(reporter: FeedbackReporter(name: "App User", email: "app@example.com"))

        #expect(!session.isEditingReporter)
        #expect(session.reporterName == "App User")

        ReporterStore(defaults: defaults).save(FeedbackReporter(name: "Tester"))
        let next = try makeSession(reporter: FeedbackReporter(name: "App User"))
        #expect(next.reporterName == "Tester")
        #expect(next.reporterEmail.isEmpty)
    }

    @Test
    func invalidEmailBlocksSend() throws {
        let session = try makeSession()
        session.text = "Crash"
        session.reporterName = "Tester"
        session.reporterEmail = "tester at example"

        #expect(!session.isReporterEmailValid)
        #expect(!session.canSend)
    }

    private static func whiteImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
        }
    }

    /// The raw bytes of one part of a `multipart/form-data` body.
    private static func part(named name: String, in body: Data?) -> Data? {
        guard let body else {
            return nil
        }
        let disposition = Data("name=\"\(name)\"".utf8)
        guard let nameRange = body.range(of: disposition),
              let headerEnd = body.range(of: Data("\r\n\r\n".utf8), in: nameRange.upperBound ..< body.endIndex),
              let partEnd = body.range(of: Data("\r\n--".utf8), in: headerEnd.upperBound ..< body.endIndex)
        else {
            return nil
        }
        return body.subdata(in: headerEnd.upperBound ..< partEnd.lowerBound)
    }

    private static func metadata(in body: Data?) throws -> [String: Any] {
        let json = try #require(part(named: "metadata", in: body))
        return try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
    }

    private static func pixel(of image: UIImage, x: Int, y: Int) throws -> [UInt8] {
        let cgImage = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(
            x: -CGFloat(x),
            y: -CGFloat(cgImage.height) + CGFloat(y + 1),
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        ))
        return Array(bytes[0 ..< 3])
    }
}

/// Accepts every report with 201 and keeps its body.
private final class CaptureProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var bodies: [Data] = []

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.bodies.append(Self.body(of: request))
        let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands the body to protocols as a stream.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
