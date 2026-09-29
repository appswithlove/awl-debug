import Foundation

extension NetworkLog {

    /// Replays the stored (redacted) request. Redacted values stay `[REDACTED]`.
    var curlCommand: String {
        var command = "curl"
        if method != "GET" || requestBody != nil {
            command += " -X \(method)"
        }
        var lines = [command + " " + Self.shellQuoted(url)]
        lines += requestHeaders.map { "-H " + Self.shellQuoted("\($0.name): \($0.value)") }

        var omittedBodyReason: String?
        if let body = requestBody {
            if body.isText && !body.truncated {
                lines.append("--data-raw " + Self.shellQuoted(body.text))
            } else {
                omittedBodyReason = body.truncated ? "truncated" : body.text
            }
        }

        var result = lines.joined(separator: " \\\n  ")
        if let omittedBodyReason = omittedBodyReason {
            result += "\n# body not included: \(omittedBodyReason)"
        }
        return result
    }

    /// `<ISO time> <METHOD> <status> <durationMs>ms <url>`, followed by indented headers and bodies.
    var exportText: String {
        var lines = ["\(Self.isoFormatter.string(from: date)) \(method) \(statusCode) \(duration)ms \(url)"]
        if let errorDescription = errorDescription {
            lines.append("  \(LS.Network.error): \(errorDescription)")
        }
        lines += Self.exportSection(LS.Network.requestHeaders, headers: requestHeaders, body: nil)
        lines += Self.exportSection(LS.Network.requestBody, headers: nil, body: requestBody)
        lines += Self.exportSection(LS.Network.responseHeaders, headers: responseHeaders, body: nil)
        lines += Self.exportSection(LS.Network.responseBody, headers: nil, body: responseBody)
        return lines.joined(separator: "\n")
    }

    private static func exportSection(_ title: String, headers: [Header]?, body: Body?) -> [String] {
        var lines = ["  \(title):"]
        if let headers = headers {
            lines += headers.map { "    \($0.name): \($0.value)" }
        } else {
            let text = body.map { $0.truncated ? $0.text + "\n" + LS.Network.truncated($0.originalBytes) : $0.text } ?? LS.Network.noBody
            lines += text.components(separatedBy: .newlines).map { "    " + $0 }
        }
        return lines
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
