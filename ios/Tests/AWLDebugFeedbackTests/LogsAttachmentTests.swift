//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Foundation
import Testing
import UIKit

struct LogsAttachmentTests {
    private static let golden: Data = {
        let url = Bundle.module.url(forResource: "logs", withExtension: "txt", subdirectory: "Fixtures")!
        return try! Data(contentsOf: url)
    }()

    /// Everything from the `filters:` line on, as the debug tool delivers it.
    private static var goldenBody: Data {
        let text = String(decoding: golden, as: UTF8.self)
        return Data(text[text.range(of: "filters:")!.lowerBound...].utf8)
    }

    private static func config(distribution: AWLDistribution? = .internal, attachLogsByDefault: Bool = true) -> FeedbackConfig {
        FeedbackConfig(endpoint: URL(string: "https://feedback.example.com")!, appKey: "key-123", appVersion: "2.3.0",
                       buildNumber: "1024", environment: "staging", distribution: distribution,
                       attachLogsByDefault: attachLogsByDefault)
    }

    private static let generatedAt = ISO8601DateFormatter().date(from: "2026-09-29T08:15:31Z")!
    private static let zurich = TimeZone(identifier: "Europe/Zurich")!

    /// Same file as the Android SDK's golden `logs.txt`.
    @MainActor
    @Test
    func headerAndToolPartMatchGoldenFile() async {
        let header = LogsAttachment.header(config: Self.config(), device: ["android 16", "Google Pixel 9", "de-CH"],
                                           generatedAt: Self.generatedAt, timeZone: Self.zurich)

        let data = await LogsAttachment.capture(header: header, source: { Self.goldenBody })

        #expect(data == Self.golden)
    }

    @Test
    func headerDescribesTheIOSDevice() {
        let header = LogsAttachment.header(config: Self.config(distribution: nil), device: ["ios 26.0", "iPhone17,1", "de-CH"],
                                           generatedAt: Self.generatedAt, timeZone: TimeZone(identifier: "UTC")!)

        #expect(header == """
        # AWL Debug logs
        app: 2.3.0 (1024) · staging
        device: ios 26.0 · iPhone17,1 · de-CH
        generated: 2026-09-29T08:15:31.000Z

        """)
    }

    @Test
    func headerValuesStayOnOneLine() {
        let config = FeedbackConfig(endpoint: URL(string: "https://feedback.example.com")!, appKey: "k", appVersion: "1\n2",
                                    buildNumber: "3\r4", environment: "x\u{0}y")
        let header = LogsAttachment.header(config: config, device: ["ios 26.0"], generatedAt: Self.generatedAt, timeZone: Self.zurich)

        #expect(header.contains("app: 1 2 (3 4) · x y\n"))
    }

    @MainActor
    @Test
    func tooLargeOrMissingPartIsLeftOut() async {
        let tooLarge = await LogsAttachment.capture(header: "# AWL Debug logs\n",
                                                    source: { Data(repeating: 0x61, count: LogsAttachment.maxBytes) })
        let withoutTool = await LogsAttachment.capture(header: "# AWL Debug logs\n", source: nil)
        let empty = await LogsAttachment.capture(header: "# AWL Debug logs\n", source: { nil })

        #expect(tooLarge == nil)
        #expect(withoutTool == nil)
        #expect(empty == nil)
    }

    @Test
    func requestCarriesLogsPart() throws {
        let metadata = FeedbackMetadata(osVersion: "26.0", deviceModel: "iPhone17,1", appVersion: "1.0", buildNumber: "42",
                                        environment: "staging", locale: "de-CH", extraMetadata: [:], date: Self.generatedAt)
        let client = FeedbackClient(endpoint: URL(string: "https://feedback.example.com")!, appKey: "key-123")

        let request = try client.makeRequest(text: "t", metadata: metadata, screenshotJPEG: Data([0xff]), logs: Self.golden,
                                             idempotencyKey: UUID())

        let body = try #require(request.httpBody)
        let part = Data("Content-Disposition: form-data; name=\"logs\"; filename=\"logs.txt\"\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n".utf8)
            + Self.golden + Data("\r\n".utf8)
        #expect(body.range(of: part) != nil)
    }

    @MainActor
    @Test
    func switchFollowsConfigAndOnlyShowsWithTheTool() {
        let screenshot = UIImage()
        // The test process does not contain AWLDebugTool, so the bridge is not found.
        #expect(LogsAttachment.toolSource == nil)
        #expect(!FeedbackSession(screenshot: screenshot, config: Self.config()).canAttachLogs)

        let withTool = FeedbackSession(screenshot: screenshot, config: Self.config(), logsSource: { Self.goldenBody })
        let off = FeedbackSession(screenshot: screenshot, config: Self.config(attachLogsByDefault: false), logsSource: { nil })
        #expect(withTool.canAttachLogs && withTool.attachLogs)
        #expect(off.canAttachLogs && !off.attachLogs)
    }
}
