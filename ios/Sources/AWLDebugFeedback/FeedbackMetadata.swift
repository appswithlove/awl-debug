//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// The `metadata` field of a report, encoded as a JSON string.
struct FeedbackMetadata: Encodable, Equatable {
    static let maxExtraEntries = 30
    static let maxValueLength = 500
    static let maxKeyLength = 64
    /// Limit of the service for every other string.
    static let maxStringLength = 200
    static let maxEmailLength = 254
    static let screenKey = "screen"

    let platform: String
    let osVersion: String
    let deviceModel: String
    let appVersion: String
    let buildNumber: String
    let environment: String
    let distribution: AWLDistribution?
    let locale: String
    let screen: String?
    let timestamp: String
    let extra: [String: String]
    let reporter: Reporter?

    struct Reporter: Encodable, Equatable {
        let name: String
        let email: String?
    }

    init(
        osVersion: String,
        deviceModel: String,
        appVersion: String,
        buildNumber: String,
        environment: String,
        locale: String,
        extraMetadata: [String: String],
        date: Date,
        distribution: AWLDistribution? = nil,
        reporter: FeedbackReporter? = nil
    ) {
        platform = "ios"
        self.osVersion = Self.short(osVersion)
        self.deviceModel = Self.short(deviceModel)
        self.appVersion = Self.short(appVersion)
        self.buildNumber = Self.short(buildNumber)
        self.environment = Self.short(environment)
        self.distribution = distribution
        self.locale = Self.short(locale)
        screen = extraMetadata[Self.screenKey].map(Self.short)
        timestamp = date.formatted(.iso8601)
        extra = Self.limited(extraMetadata)
        self.reporter = reporter.flatMap(Self.reporter)
    }

    /// BCP 47 (`de-CH`), the format every platform sends.
    static func localeIdentifier(_ locale: Locale) -> String {
        locale.identifier(.bcp47)
    }

    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try String(bytes: encoder.encode(self), encoding: .utf8) ?? ""
    }

    /// The service rejects more than 30 entries and keys that are empty or longer than 64
    /// characters; sorting keeps the kept subset deterministic.
    private static func limited(_ metadata: [String: String]) -> [String: String] {
        let entries = metadata
            .filter { !$0.key.isEmpty && $0.key.utf16.count <= maxKeyLength }
            .sorted { $0.key < $1.key }
            .prefix(maxExtraEntries)
            .map { ($0.key, capped($0.value)) }
        return Dictionary(uniqueKeysWithValues: entries)
    }

    private static func capped(_ value: String) -> String {
        value.prefix(utf16Units: maxValueLength)
    }

    private static func short(_ value: String) -> String {
        value.prefix(utf16Units: maxStringLength)
    }

    /// The service requires a non-blank name and rejects malformed addresses, so a blank name
    /// drops the reporter and an unusable address drops only the address.
    private static func reporter(_ reporter: FeedbackReporter) -> Reporter? {
        let name = reporter.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }
        let email = reporter.email
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { isValidEmail($0) ? $0 : nil }
        return Reporter(name: short(name), email: email)
    }

    /// The service's rule (zod `z.email()`): ASCII local part without leading, trailing or double dots, a domain
    /// with a dot and a TLD of at least two letters. The service rejects the whole report for any other address.
    static func isValidEmail(_ email: String) -> Bool {
        email.utf16.count <= maxEmailLength && email.range(of: emailPattern, options: .regularExpression) != nil
    }

    private static let emailPattern =
        #"^(?:[A-Za-z0-9_'+\-]+\.)*[A-Za-z0-9_'+\-]*[A-Za-z0-9_+-]@(?:[A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}\z"#
}

extension String {
    /// At most `maxLength` UTF-16 units, the way the service counts string lengths, without splitting a character.
    func prefix(utf16Units maxLength: Int) -> String {
        guard utf16.count > maxLength else {
            return self
        }
        var units = 0
        let end = firstIndex { character in
            units += character.utf16.count
            return units > maxLength
        } ?? endIndex
        return String(self[..<end])
    }
}
