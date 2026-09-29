//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation
import ObjectiveC

/// `logs.txt` for a report: the header written here, followed by logs and requests from `AWLDebugTool`.
/// The tool is reached at runtime through its `AWLDebugToolBridge` class, so this product does not link it.
enum LogsAttachment {
    /// The service accepts `logs.txt` up to 1 MiB.
    static let maxBytes = 1024 * 1024
    private static let maxHeaderValueLength = 200

    /// Returns the tool's part of `logs.txt`, starting with its `filters:` line.
    typealias Source = @MainActor () async -> Data?

    /// `nil` without `AWLDebugTool` in the app or before `AWLDebugTool.start`.
    static var toolSource: Source? {
        guard let bridge = NSClassFromString("AWLDebugToolBridge"),
              let isAvailable = classMethod(of: bridge, "isAvailable", as: IsAvailable.self),
              isAvailable(bridge, NSSelectorFromString("isAvailable")),
              let attachment = classMethod(of: bridge, "feedbackLogsAttachment:", as: FeedbackLogsAttachment.self) else {
            return nil
        }
        return {
            await withCheckedContinuation { continuation in
                attachment(bridge, NSSelectorFromString("feedbackLogsAttachment:")) { data in
                    continuation.resume(returning: data)
                }
            }
        }
    }

    /// Header plus the source's part, or `nil` without a source or when the result is larger than the service accepts.
    @MainActor
    static func capture(header: String, source: Source?) async -> Data? {
        guard let body = await source?() else {
            return nil
        }
        let data = Data(header.utf8) + body
        return data.count <= maxBytes ? data : nil
    }

    /// `device` is platform with OS version, model and locale, e.g. `["ios 26.0", "iPhone17,1", "de-CH"]`.
    static func header(config: FeedbackConfig, device: [String], generatedAt: Date, timeZone: TimeZone) -> String {
        let app = ["\(headerValue(config.appVersion)) (\(headerValue(config.buildNumber)))", headerValue(config.environment)]
            + [config.distribution?.rawValue].compactMap { $0 }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
        return """
        # AWL Debug logs
        app: \(app.joined(separator: " · "))
        device: \(device.map(headerValue).joined(separator: " · "))
        generated: \(formatter.string(from: generatedAt))

        """
    }

    /// Single line, capped like the metadata strings, so the header always fits the room the tool leaves for it.
    private static func headerValue(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { "\r\n\u{0}".unicodeScalars.contains($0) ? " " : $0 }
        return String(String(String.UnicodeScalarView(scalars)).prefix(maxHeaderValueLength))
    }

    private typealias IsAvailable = @convention(c) (AnyClass, Selector) -> Bool
    private typealias FeedbackLogsAttachment = @convention(c) (AnyClass, Selector, @escaping @convention(block) (Data?) -> Void) -> Void

    /// Implementation of a class method of the tool bridge, called through a `@convention(c)` type.
    static func classMethod<Function>(of type: AnyClass, _ selector: String, as _: Function.Type) -> Function? {
        guard let method = class_getClassMethod(type, NSSelectorFromString(selector)) else {
            return nil
        }
        return unsafeBitCast(method_getImplementation(method), to: Function.self)
    }
}
