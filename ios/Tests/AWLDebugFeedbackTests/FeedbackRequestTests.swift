//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

@testable import AWLDebugFeedback
import Foundation
import Testing

struct FeedbackRequestTests {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func metadata(
        extra: [String: String] = [:],
        appVersion: String = "1.0",
        distribution: AWLDistribution? = nil,
        reporter: FeedbackReporter? = nil
    ) -> FeedbackMetadata {
        FeedbackMetadata(
            osVersion: "26.0",
            deviceModel: "iPhone17,1",
            appVersion: appVersion,
            buildNumber: "42",
            environment: "staging",
            locale: "de-CH",
            extraMetadata: extra,
            date: date,
            distribution: distribution,
            reporter: reporter
        )
    }

    private func jsonObject(_ metadata: FeedbackMetadata) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(metadata.jsonString().utf8)) as? [String: Any])
    }

    @Test
    func metadataEncodesContractFields() throws {
        let json = try metadata(extra: ["screen": "ProductDetail", "itemId": "7"]).jsonString()

        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["platform"] as? String == "ios")
        #expect(object["osVersion"] as? String == "26.0")
        #expect(object["deviceModel"] as? String == "iPhone17,1")
        #expect(object["appVersion"] as? String == "1.0")
        #expect(object["buildNumber"] as? String == "42")
        #expect(object["environment"] as? String == "staging")
        #expect(object["locale"] as? String == "de-CH")
        #expect(object["screen"] as? String == "ProductDetail")
        #expect(object["timestamp"] as? String == "2026-09-21T14:13:20Z")
        #expect(object["extra"] as? [String: String] == ["screen": "ProductDetail", "itemId": "7"])
    }

    @Test(arguments: [("de_CH", "de-CH"), ("fr_CH", "fr-CH"), ("en", "en")])
    func localeIsBCP47(identifier: String, expected: String) {
        #expect(FeedbackMetadata.localeIdentifier(Locale(identifier: identifier)) == expected)
    }

    @Test
    func metadataOmitsMissingScreen() throws {
        let json = try metadata().jsonString()

        #expect(!json.contains("\"screen\""))
    }

    @Test
    func metadataCapsExtraEntriesAndValues() {
        let many = Dictionary(uniqueKeysWithValues: (0 ..< 40).map { (
            String(format: "k%02d", $0),
            String(repeating: "x", count: 600)
        ) })

        let extra = metadata(extra: many).extra

        #expect(extra.count == FeedbackMetadata.maxExtraEntries)
        #expect(extra["k00"]?.count == FeedbackMetadata.maxValueLength)
        #expect(extra["k39"] == nil)
    }

    /// Older feedback services reject unknown keys with 400, so the default request keeps exactly today's keys.
    @Test
    func metadataWithoutOptionalFieldsKeepsTodaysKeys() throws {
        let object = try jsonObject(metadata(extra: ["screen": "ProductDetail"]))

        #expect(Set(object.keys) == [
            "platform", "osVersion", "deviceModel", "appVersion", "buildNumber",
            "environment", "locale", "screen", "timestamp", "extra"
        ])
    }

    @Test
    func metadataEncodesDistributionAndReporter() throws {
        let object = try jsonObject(metadata(
            distribution: .internal,
            reporter: FeedbackReporter(name: " Tester 3 ", email: "tester@example.com")
        ))

        #expect(object["distribution"] as? String == "internal")
        #expect(object["reporter"] as? [String: String] == ["name": "Tester 3", "email": "tester@example.com"])
    }

    @Test
    func metadataDropsUnusableReporterValues() throws {
        #expect(try jsonObject(metadata(reporter: FeedbackReporter(name: "  "))).keys.contains("reporter") == false)

        let object = try jsonObject(metadata(reporter: FeedbackReporter(name: "Tester", email: "tester at example")))
        #expect(object["reporter"] as? [String: String] == ["name": "Tester"])
    }

    @Test
    func metadataCapsStringsAtServiceLimit() {
        let long = String(repeating: "s", count: 600)

        let metadata = metadata(extra: [FeedbackMetadata.screenKey: long], appVersion: long)

        #expect(metadata.screen?.count == FeedbackMetadata.maxStringLength)
        #expect(metadata.appVersion.count == FeedbackMetadata.maxStringLength)
        #expect(metadata.extra[FeedbackMetadata.screenKey]?.count == FeedbackMetadata.maxValueLength)
    }

    @Test
    func metadataDropsEmptyAndOverlongExtraKeys() {
        let extra = metadata(extra: [
            "": "empty",
            String(repeating: "k", count: 65): "too long",
            String(repeating: "k", count: 64): "longest allowed",
        ]).extra

        #expect(extra == [String(repeating: "k", count: 64): "longest allowed"])
    }

    @Test
    func requestIsMultipartWithAppKey() throws {
        let client = try FeedbackClient(
            endpoint: #require(URL(string: "https://feedback.example.com")),
            appKey: "key-123"
        )
        let jpeg = Data([0xff, 0xd8, 0xff, 0xd9])

        let request = try client.makeRequest(text: "Button is cut off", metadata: metadata(), screenshotJPEG: jpeg)

        #expect(request.url?.absoluteString == "https://feedback.example.com/v1/feedback")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-App-Key") == "key-123")
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))

        let body = try #require(request.httpBody)
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        // Latin-1 maps every byte, so the binary JPEG part cannot fail the conversion.
        let text = try #require(String(bytes: body, encoding: .isoLatin1))
        #expect(text
            .contains("--\(boundary)\r\nContent-Disposition: form-data; name=\"text\"\r\n\r\nButton is cut off\r\n"))
        #expect(text.contains("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n{\"appVersion\":\"1.0\""))
        let screenshotHeader = "Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.jpg\"\r\n"
        #expect(text.contains(screenshotHeader + "Content-Type: image/jpeg\r\n\r\n"))
        #expect(body.firstRange(of: jpeg) != nil)
        #expect(text.hasSuffix("--\(boundary)--\r\n"))
    }

    @Test(arguments: [
        (400, nil, FeedbackError.invalidRequest),
        (401, nil, .unauthorized),
        (413, nil, .tooLarge),
        (415, nil, .unsupportedMediaType),
        (429, "30", .rateLimited(retryAfterSeconds: 30)),
        (429, nil, .rateLimited(retryAfterSeconds: nil)),
        (502, nil, .serviceUnavailable),
        (503, nil, .serviceUnavailable),
        (418, nil, .unexpectedStatus(418))
    ] as [(Int, String?, FeedbackError)])
    func statusMapsToError(statusCode: Int, retryAfter: String?, expected: FeedbackError) {
        #expect(FeedbackError(statusCode: statusCode, retryAfter: retryAfter) == expected)
    }

    @Test
    func networkErrorsMapToReadableMessages() {
        #expect(FeedbackError(urlError: URLError(.notConnectedToInternet)) == .offline)
        #expect(FeedbackError(urlError: URLError(.timedOut)) == .network)
        #expect(FeedbackError.rateLimited(retryAfterSeconds: 30)
            .message == "Too many reports. Try again in 30 seconds.")
    }
}
