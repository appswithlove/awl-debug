import Foundation

/// Logs and requests for the feedback attachment `logs.txt`. The feedback product writes the header, this
/// is everything from the `filters:` line on. Same format as the Android SDK.
enum LogsAttachment {
    static let maxLogs = 500
    static let maxRequests = 50
    /// Room left in the 1 MiB `logs.txt` for the header that the feedback product writes.
    static let bodyMaxBytes = 1024 * 1024 - 4 * 1024
    private static let indent = "    "

    @MainActor
    static func current(logs: AppLogsStore, network: NetworkLogger) -> String {
        body(logs: Array(logs.filteredEntries.suffix(maxLogs)),
             filters: describeFilters(levels: logs.selectedLevels, search: logs.searchText),
             // Stored when finished; the attachment lists them by start time.
             requests: network.networkTraffic.suffix(maxRequests).sorted { $0.date < $1.date },
             maxBytes: bodyMaxBytes,
             timeZone: .current)
    }

    /// `filters:` value, e.g. `severity=ERROR,WARN search="checkout"`, or `none`.
    static func describeFilters(levels: Set<AWLDebugLogLevel>, search: String) -> String {
        var parts: [String] = []
        if !levels.isEmpty {
            parts.append("severity=" + AWLDebugLogLevel.allCases.reversed().filter(levels.contains).map(\.rawValue).joined(separator: ","))
        }
        if !search.isEmpty {
            parts.append("search=\"" + search.replacingOccurrences(of: "\"", with: "\\\"") + "\"")
        }
        return parts.isEmpty ? "none" : parts.joined(separator: " ")
    }

    /// `logs` and `requests` are already redacted, oldest first. When the text would exceed `maxBytes`,
    /// the oldest logs are left out first, then the oldest requests.
    static func body(logs: [AppLogEntry], filters: String, requests: [NetworkLog], maxBytes: Int, timeZone: TimeZone) -> String {
        let formatter = dateFormatter(timeZone: timeZone)
        let logBlocks = logs.map { text(of: $0, formatter: formatter) }
        let requestBlocks = requests.map { text(of: $0, formatter: formatter) }
        let filtersLine = "filters: \(filters.cleaned)\n\n"
        let fixed = filtersLine + section("Logs", max: maxLogs, omitted: 0, blocks: []) + "\n" + section("Network", max: maxRequests, omitted: 0, blocks: [])
        // Room for both "omitted" lines and wider counts in the headings.
        var budget = maxBytes - fixed.utf8.count - 2 * 64
        let keptRequests = newest(requestBlocks, within: budget)
        budget -= keptRequests.reduce(0) { $0 + $1.utf8.count }
        let keptLogs = newest(logBlocks, within: budget)
        return filtersLine +
            section("Logs", max: maxLogs, omitted: logBlocks.count - keptLogs.count, blocks: keptLogs) +
            "\n" +
            section("Network", max: maxRequests, omitted: requestBlocks.count - keptRequests.count, blocks: keptRequests)
    }

    /// RFC 3339 with milliseconds and the offset of `timeZone`.
    static func dateFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
        return formatter
    }

    private static func section(_ title: String, max: Int, omitted: Int, blocks: [String]) -> String {
        var text = "## \(title) (\(blocks.count) of \(max))\n"
        if omitted > 0 {
            text += "… \(omitted) older entries omitted\n"
        }
        return text + blocks.joined()
    }

    /// Newest blocks that fit into `budget` bytes together, oldest first; stops at the first one that does not fit.
    private static func newest(_ blocks: [String], within budget: Int) -> [String] {
        var left = budget
        var kept: [String] = []
        for block in blocks.reversed() {
            let size = block.utf8.count
            if size > left {
                break
            }
            left -= size
            kept.append(block)
        }
        return kept.reversed()
    }

    private static func text(of entry: AppLogEntry, formatter: DateFormatter) -> String {
        let lines = entry.message.cleaned.components(separatedBy: "\n")
        let tag = entry.tag.map(\.cleaned).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? "-"
        var text = "\(formatter.string(from: entry.date)) | \(entry.level.rawValue) | \(tag) | \(lines[0])\n"
        for line in lines.dropFirst() {
            text += indent + line + "\n"
        }
        if let error = entry.errorDescription {
            for line in error.cleaned.trimmingTrailingWhitespace.components(separatedBy: "\n") {
                text += indent + line.replacingOccurrences(of: "\t", with: indent) + "\n"
            }
        }
        return text
    }

    private static func text(of log: NetworkLog, formatter: DateFormatter) -> String {
        let isFailed = log.statusCode == 0 || log.errorCode != nil
        var text = "\(formatter.string(from: log.date)) \(log.method) \(isFailed ? "-" : String(log.statusCode)) \(log.duration)ms \(log.url.cleaned)\n"
        for header in log.requestHeaders {
            text += "\(indent)> \(header.name.lowercased()): \(header.value.cleaned)\n"
        }
        for header in log.responseHeaders {
            text += "\(indent)< \(header.name.lowercased()): \(header.value.cleaned)\n"
        }
        if isFailed {
            // Without an error the app cancelled the request.
            text += "\(indent)! \(log.errorCode ?? "cancelled")\n"
        }
        return text
    }
}

extension NetworkLog {
    /// Short failure code, as in the session batch: `timeout`, `dns`, `tls`, `cancelled` or `connection`.
    static func errorCode(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "connection"
        }
        switch urlError.code {
        case .timedOut:
            return "timeout"
        case .cannotFindHost, .dnsLookupFailed:
            return "dns"
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
             .clientCertificateRequired, .appTransportSecurityRequiresSecureConnection:
            return "tls"
        case .cancelled:
            return "cancelled"
        default:
            return "connection"
        }
    }
}

private extension String {
    /// One line ending, no NUL bytes: the service rejects `logs.txt` with NUL bytes.
    var cleaned: String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{0}", with: "\u{FFFD}")
    }

    var trimmingTrailingWhitespace: String {
        guard let last = lastIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        return String(self[...last])
    }
}
