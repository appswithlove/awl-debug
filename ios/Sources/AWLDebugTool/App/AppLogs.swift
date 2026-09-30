import Foundation
import OSLog

public enum AWLDebugLogLevel: String, CaseIterable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

struct AppLogEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let level: AWLDebugLogLevel
    let tag: String?
    let message: String
    /// Type and description of an attached error.
    let errorDescription: String?
}

extension String {
    private static let bearerPattern = try! NSRegularExpression(pattern: #"\b(Bearer)\s+[A-Za-z0-9\-._~+/]+=*"#, options: .caseInsensitive)
    private static let basicPattern = try! NSRegularExpression(pattern: #"\b(Basic)\s+([A-Za-z0-9+/]+={0,2})"#, options: .caseInsensitive)

    /// Replaces `Bearer <token>` and `Basic <credentials>` with `Bearer [REDACTED]` / `Basic [REDACTED]`.
    /// `Basic` is only redacted when it is followed by Base64 of `user:password`, so prose such as
    /// "Basic setup" stays readable.
    func redactingCredentials() -> String {
        var result = Self.bearerPattern.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self),
                                                                 withTemplate: "$1 \(NetworkRedactor.placeholder)")
        for match in Self.basicPattern.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
            guard let range = Range(match.range, in: result),
                  let keyword = Range(match.range(at: 1), in: result),
                  let value = Range(match.range(at: 2), in: result),
                  let decoded = Data(base64Encoded: String(result[value])).flatMap({ String(data: $0, encoding: .utf8) }),
                  decoded.contains(":") else {
                continue
            }
            result.replaceSubrange(range, with: "\(result[keyword]) \(NetworkRedactor.placeholder)")
        }
        return result
    }
}

extension String {
    /// `"key":` or, inside stringified JSON, `\"key\":`. Group 1 is the quote, group 2 the key.
    private static let jsonKeyPattern = try! NSRegularExpression(pattern: #"(\\?")([A-Za-z0-9_\-]+)\1\s*:\s*"#)
    static let defaultRedactedFields = Set(AWLDebugConfig.NetworkConfig.defaultRedactedFields.map(NetworkRedactor.normalizedFieldName))

    /// Credentials and sensitive JSON fields redacted, as stored in the Logs module.
    func redactingSecrets() -> String {
        redactingCredentials().redactingJsonFields()
    }

    /// Replaces the values of sensitive JSON fields with `"[REDACTED]"`, using the network module's default
    /// field list. Works on JSON inside free text, on stringified JSON (`\"password\":\"…\"`) and on truncated
    /// JSON, where an unterminated value is redacted to the end. Keys match ignoring case, `_` and `-`.
    func redactingJsonFields(_ fieldNames: Set<String> = defaultRedactedFields) -> String {
        let text = Array(utf16)
        let nsText = self as NSString
        var result: [UInt16] = []
        var copiedUntil = 0
        var searchFrom = 0
        while searchFrom < text.count,
              let match = Self.jsonKeyPattern.firstMatch(in: self, range: NSRange(location: searchFrom, length: text.count - searchFrom)) {
            let valueStart = match.range.location + match.range.length
            let key = nsText.substring(with: match.range(at: 2))
            guard fieldNames.contains(NetworkRedactor.normalizedFieldName(key)), valueStart < text.count else {
                searchFrom = match.range.location + 1
                continue
            }
            let quote = Array(nsText.substring(with: match.range(at: 1)).utf16)
            let valueEnd = Self.jsonValueEnd(text, start: valueStart, quote: quote)
            result += text[copiedUntil..<valueStart] + quote + Array(NetworkRedactor.placeholder.utf16) + quote
            copiedUntil = valueEnd
            searchFrom = valueEnd
        }
        guard copiedUntil > 0 else {
            return self
        }
        result += text[copiedUntil...]
        return String(utf16CodeUnits: result, count: result.count)
    }

    private static let backslash = UInt16(UInt8(ascii: "\\"))
    private static let doubleQuote = UInt16(UInt8(ascii: "\""))

    /// Exclusive end index of the JSON value starting at `start`.
    private static func jsonValueEnd(_ text: [UInt16], start: Int, quote: [UInt16]) -> Int {
        if hasPrefix(text, quote, at: start) {
            return jsonStringEnd(text, contentStart: start + quote.count, quote: quote)
        }
        if text[start] == UInt16(UInt8(ascii: "{")) || text[start] == UInt16(UInt8(ascii: "[")) {
            return jsonContainerEnd(text, start: start)
        }
        let terminators: Set<UInt16> = Set(",}]\n\r \t".utf16)
        return text[start...].firstIndex(where: terminators.contains) ?? text.count
    }

    private static func jsonStringEnd(_ text: [UInt16], contentStart: Int, quote: [UInt16]) -> Int {
        let isEscapedQuote = quote.count == 2
        var index = contentStart
        while index < text.count {
            if isEscapedQuote && hasPrefix(text, [backslash, backslash], at: index) {
                index += 2
            } else if hasPrefix(text, quote, at: index) {
                return index + quote.count
            } else if !isEscapedQuote && text[index] == backslash {
                index += 2
            } else {
                index += 1
            }
        }
        return text.count
    }

    private static func jsonContainerEnd(_ text: [UInt16], start: Int) -> Int {
        var depth = 0
        var inString = false
        var index = start
        while index < text.count {
            let unit = text[index]
            if inString && unit == backslash {
                index += 1
            } else if unit == doubleQuote {
                inString.toggle()
            } else if !inString {
                if unit == UInt16(UInt8(ascii: "{")) || unit == UInt16(UInt8(ascii: "[")) {
                    depth += 1
                } else if unit == UInt16(UInt8(ascii: "}")) || unit == UInt16(UInt8(ascii: "]")) {
                    depth -= 1
                    if depth == 0 {
                        return index + 1
                    }
                }
            }
            index += 1
        }
        return text.count
    }

    private static func hasPrefix(_ text: [UInt16], _ prefix: [UInt16], at index: Int) -> Bool {
        index + prefix.count <= text.count && Array(text[index..<index + prefix.count]) == prefix
    }
}

/// Reads the process's own unified-log entries (`os_log`, `Logger`, Kermit's `OSLogWriter`).
struct OSLogReader {
    let subsystems: Set<String>?

    /// Entries after `date`, oldest first.
    func entries(after date: Date?) throws -> [AppLogEntry] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = date.map { store.position(date: $0) }
        let ownSubsystem = Bundle.main.bundleIdentifier ?? ""
        return try store.getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { entry in
                if let date = date, entry.date <= date {
                    return false
                }
                return isIncluded(subsystem: entry.subsystem)
            }
            .map { entry in
                let tag: String?
                if entry.subsystem.isEmpty || entry.subsystem == ownSubsystem {
                    tag = entry.category.isEmpty ? nil : entry.category
                } else {
                    tag = entry.category.isEmpty ? entry.subsystem : "\(entry.subsystem)/\(entry.category)"
                }
                return AppLogEntry(date: entry.date, level: Self.level(of: entry.level), tag: tag,
                                   message: entry.composedMessage.redactingSecrets(), errorDescription: nil)
            }
    }

    /// Without an explicit list, Apple's own frameworks are left out: they would drown the app's entries.
    func isIncluded(subsystem: String) -> Bool {
        if let subsystems = subsystems {
            return subsystems.contains(subsystem)
        }
        return !subsystem.hasPrefix("com.apple.")
    }

    static func level(of level: OSLogEntryLog.Level) -> AWLDebugLogLevel {
        switch level {
        case .info, .notice:
            return .info
        case .error, .fault:
            return .error
        case .debug, .undefined:
            return .debug
        @unknown default:
            return .debug
        }
    }
}

/// The logs buffer behind the Logs module: newest last, at most `limit` entries.
@MainActor
final class AppLogsStore: ObservableObject {
    static let pollInterval: TimeInterval = 2

    @Published private(set) var entries: [AppLogEntry] = []
    @Published var searchText = ""
    /// No selection shows every level.
    @Published var selectedLevels: Set<AWLDebugLogLevel> = []
    @Published var isRecording: Bool {
        didSet { defaults.set(isRecording, forKey: Constants.UserDefaultsKey.appLogsRecording) }
    }
    @Published var limit: Int {
        didSet {
            defaults.set(limit, forKey: Constants.UserDefaultsKey.appLogsLimit)
            trimToLimit()
        }
    }

    var config = AWLDebugConfig.LogsConfig()
    /// `false` until the first read of the unified log has finished; the Logs page shows a spinner until then.
    @Published private(set) var hasReadOSLog = false

    private let defaults: UserDefaults
    /// Unified-log entries up to this date are read; `clear()` moves it forward.
    private var readUntil: Date?
    private var isReading = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isRecording = defaults.object(forKey: Constants.UserDefaultsKey.appLogsRecording) as? Bool ?? true
        let storedLimit = defaults.integer(forKey: Constants.UserDefaultsKey.appLogsLimit)
        limit = storedLimit > 0 ? storedLimit : Constants.Defaults.defaultLogLimit
    }

    var filteredEntries: [AppLogEntry] {
        entries.filter { entry in
            (selectedLevels.isEmpty || selectedLevels.contains(entry.level)) &&
            (searchText.isEmpty ||
             entry.message.localizedCaseInsensitiveContains(searchText) ||
             (entry.tag?.localizedCaseInsensitiveContains(searchText) ?? false))
        }
    }

    func append(_ entry: AppLogEntry) {
        guard isRecording else { return }
        insert([entry])
    }

    func clear() {
        entries = []
        readUntil = Date()
    }

    /// Reads new unified-log entries off the main thread.
    func readOSLog() async {
        guard config.readOSLog, !isReading else { return }
        isReading = true
        defer {
            isReading = false
            if !hasReadOSLog {
                hasReadOSLog = true
            }
        }

        let reader = OSLogReader(subsystems: config.subsystems)
        let since = readUntil
        guard let newEntries = try? await Task.detached(priority: .utility, operation: { try reader.entries(after: since) }).value else {
            return
        }
        if let last = newEntries.last {
            readUntil = max(readUntil ?? last.date, last.date)
        }
        if isRecording {
            insert(newEntries)
        }
    }

    private func insert(_ newEntries: [AppLogEntry]) {
        guard !newEntries.isEmpty else { return }
        entries = (entries + newEntries).sorted { $0.date < $1.date }
        trimToLimit()
    }

    private func trimToLimit() {
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
    }

    // MARK: - Export

    /// Header with app info and active filters, then one line per filtered entry.
    func exportText(appInfo: String) -> String {
        var lines = [appInfo]
        let levels = selectedLevels.isEmpty ? LS.AppLogs.allLevels : AWLDebugLogLevel.allCases.filter(selectedLevels.contains).map(\.rawValue).joined(separator: ", ")
        lines.append("\(LS.AppLogs.filterLevels): \(levels)")
        lines.append("\(LS.AppLogs.filterSearch): \(searchText.isEmpty ? "-" : searchText)")
        lines.append("")
        for entry in filteredEntries {
            lines.append("\(Self.exportDateFormatter.string(from: entry.date)) | \(entry.level.rawValue) | \(entry.tag ?? "-") | \(entry.message)")
            if let errorDescription = entry.errorDescription {
                lines += errorDescription.components(separatedBy: .newlines).map { "    " + $0 }
            }
        }
        return lines.joined(separator: "\n")
    }

    static var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return "awl-debug-logs-\(formatter.string(from: Date())).txt"
    }

    static let exportDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }()
}
