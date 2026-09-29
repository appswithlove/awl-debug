import CryptoKit
import Foundation

/// Wire format of `session-batch.v1`: limits the service enforces, applied on the device.
enum ReportingJSON {
    static let maxBodyBytes = 64 * 1024
    private static let maxHeaderValue = 4096
    private static let maxHeaders = 100
    private static let maxURL = 8192
    private static let maxError = 1000
    private static let maxShortString = 200

    /// The service requires these to be redacted, on top of what `NetworkRedactor` always redacts.
    static let redactedHeaders: Set<String> = [
        "authorization", "proxy-authorization", "cookie", "set-cookie", "x-app-key", "x-api-key",
    ]

    private static let headerNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+.^_`|~-")

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let timestampLock = NSLock()

    static func timestamp(_ millis: Int64) -> String {
        timestampLock.lock()
        defer { timestampLock.unlock() }
        return timestampFormatter.string(from: Date(timeIntervalSince1970: Double(millis) / 1000))
    }

    static func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func shortString(_ value: String?) -> String {
        let trimmed = String((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxShortString))
        return trimmed.isEmpty ? "unknown" : trimmed
    }

    /// Lowercase hex SHA-256 of `appKey:appUserId`; the plain id never leaves the device.
    static func userIdentifier(appKey: String, appUserId: String) -> String {
        SHA256.hash(data: Data("\(appKey):\(appUserId)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func encode(_ object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// `nil` for requests the service cannot store, such as non-HTTP URLs.
    static func networkLog(_ log: NetworkLog, captureBodies: Bool, maxBodyBytes: Int) -> [String: Any]? {
        guard log.method.range(of: "^[A-Z]{1,16}$", options: .regularExpression) != nil,
              log.url.range(of: "^(https?|wss?)://", options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        var json: [String: Any] = [
            "ts": timestamp(millis(log.date)),
            "method": log.method,
            "url": String(log.url.prefix(maxURL)),
            "durationMs": max(log.duration, 0),
            "requestBytes": max(log.requestBytes, 0),
            "responseBytes": max(log.responseBytes, 0),
        ]
        if (100...599).contains(log.statusCode) {
            json["status"] = log.statusCode
        } else {
            let error = log.errorCode ?? log.errorDescription.map { String($0.prefix(maxError)) }
            json["error"] = (error?.isEmpty ?? true) ? "connection" : error
        }
        if let headers = headers(log.requestHeaders) {
            json["requestHeaders"] = headers
        }
        if let headers = headers(log.responseHeaders) {
            json["responseHeaders"] = headers
        }
        if captureBodies {
            let limit = min(max(maxBodyBytes, 0), Self.maxBodyBytes)
            if let body = body(log.requestBody, limit: limit) {
                json["requestBody"] = body
            }
            if let body = body(log.responseBody, limit: limit) {
                json["responseBody"] = body
            }
        }
        return json
    }

    static func metric(_ sample: ReportingMetricSample) -> [String: Any]? {
        var json: [String: Any] = ["ts": timestamp(sample.timestampMillis)]
        if let cpu = sample.cpuPercent, cpu.isFinite {
            json["cpuPercent"] = (min(max(cpu, 0), 100) * 10).rounded() / 10
        }
        if let ram = sample.ramBytes {
            json["ramBytes"] = ram
        }
        if let battery = sample.batteryPercent, (0...100).contains(battery) {
            json["batteryPercent"] = battery
        }
        if let freeze = sample.uiFreezeMs, freeze >= 0 {
            json["uiFreezeMs"] = freeze
        }
        return json.count > 1 ? json : nil
    }

    static func session(_ session: ReportingSession) -> [String: Any] {
        var device: [String: Any] = [
            "model": shortString(session.deviceModel),
            "osVersion": shortString(session.osVersion),
        ]
        if let locale = session.locale, !locale.isEmpty {
            device["locale"] = shortString(locale)
        }
        if let totalRamBytes = session.totalRamBytes {
            device["totalRamBytes"] = totalRamBytes
        }
        var json: [String: Any] = [
            "id": session.id,
            "startedAt": timestamp(session.startedAtMillis),
            "platform": "ios",
            "appVersion": shortString(session.appVersion),
            "buildNumber": shortString(session.buildNumber),
            "environment": shortString(session.environment),
            "distribution": session.distribution,
            "sdkVersion": session.sdkVersion,
            "device": device,
        ]
        if let userIdentifier = session.userIdentifier {
            json["userIdentifier"] = userIdentifier
        }
        if let endedAt = session.endedAtMillis {
            json["endedAt"] = timestamp(endedAt)
        }
        return json
    }

    private static func headers(_ headers: [NetworkLog.Header]) -> [String: String]? {
        var merged: [String: String] = [:]
        var order: [String] = []
        for header in headers {
            let name = header.name.lowercased()
            guard (1...128).contains(name.count), name.unicodeScalars.allSatisfy(headerNameCharacters.contains) else { continue }
            if let existing = merged[name] {
                merged[name] = "\(existing), \(header.value)"
            } else {
                merged[name] = header.value
                order.append(name)
            }
        }
        guard !order.isEmpty else { return nil }
        var result: [String: String] = [:]
        for name in order.prefix(maxHeaders) {
            result[name] = redactedHeaders.contains(name) ? NetworkRedactor.placeholder : String(merged[name, default: ""].prefix(maxHeaderValue))
        }
        return result
    }

    private static func body(_ body: NetworkLog.Body?, limit: Int) -> [String: Any]? {
        guard let body, body.isText else { return nil }
        let bytes = Data(body.text.utf8)
        let isCut = bytes.count > limit
        // Cutting inside a multi-byte character leaves an invalid tail; decoding drops it as U+FFFD.
        var text = isCut ? String(decoding: bytes.prefix(limit), as: UTF8.self) : body.text
        while isCut, text.hasSuffix("\u{FFFD}") {
            text.removeLast()
        }
        var json: [String: Any] = [
            "text": text,
            "truncated": body.truncated || isCut,
            "originalBytes": max(body.originalBytes, 0),
        ]
        if let contentType = body.contentType {
            json["contentType"] = String(contentType.prefix(maxShortString))
        }
        return json
    }
}
