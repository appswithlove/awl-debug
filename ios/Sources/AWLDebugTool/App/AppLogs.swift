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
                                   message: entry.composedMessage.redactingCredentials(), errorDescription: nil)
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
        defer { isReading = false }

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
