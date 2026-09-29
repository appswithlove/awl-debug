import Foundation

/// Options passed to `AWLDebugTool.start(config:)`.
public struct AWLDebugConfig {
    public var network: NetworkConfig
    public var logs: LogsConfig
    /// App-group `UserDefaults` suites that "Clear App Data" also empties.
    public var appGroupIdentifiers: [String] = []

    public init(network: NetworkConfig = NetworkConfig(), logs: LogsConfig = LogsConfig()) {
        self.network = network
        self.logs = logs
    }

    public struct LogsConfig {
        /// Shows the app's own unified-log entries (`os_log`, `Logger`, Kermit) in the Logs module.
        public var readOSLog: Bool
        /// Subsystems to show. `nil` shows every subsystem of the process except Apple's own (`com.apple.*`).
        public var subsystems: Set<String>?

        public init(readOSLog: Bool = true, subsystems: Set<String>? = nil) {
            self.readOSLog = readOSLog
            self.subsystems = subsystems
        }
    }

    /// Shows "AWL <version> (<build>)" at the top left over the app. Testers can still switch it off in the panel.
    public var showVersionOverlay: Bool = true

    public struct NetworkConfig {
        /// Default field names redacted in JSON and form bodies and in query parameters.
        public static let defaultRedactedFields: Set<String> = [
            "password", "secret", "token", "accessToken", "refreshToken", "idToken", "credential", "apiKey", "clientSecret"
        ]

        /// Captures request and response bodies. Headers, URL and status are always captured.
        public var captureBodies: Bool
        /// Maximum stored size per body, applied after redaction.
        public var maxBodyBytes: Int
        /// Header names (case-insensitive) whose values are redacted, in addition to
        /// `Authorization`, `Proxy-Authorization`, `Cookie` and `Set-Cookie`, which are always redacted.
        public var redactHeaders: Set<String>
        /// JSON and form field names whose values are redacted, at any depth.
        /// Compared case-insensitively and ignoring `_` and `-` (`accessToken` matches `access_token`).
        public var redactJsonFields: Set<String>
        /// Query parameter names whose values are redacted, compared like `redactJsonFields`.
        public var redactQueryParams: Set<String>
        /// Request and response content types whose bodies are never read, in addition to
        /// `text/event-stream` and `application/x-ndjson`. Responses with status 101 are never read either.
        public var streamContentTypes: Set<String>
        /// Requests slower than this are labelled "slow" in the list.
        public var slowRequestThresholdMs: Int

        public init(captureBodies: Bool = true,
                    maxBodyBytes: Int = 256 * 1024,
                    redactHeaders: Set<String> = [],
                    redactJsonFields: Set<String> = defaultRedactedFields,
                    redactQueryParams: Set<String> = defaultRedactedFields,
                    streamContentTypes: Set<String> = [],
                    slowRequestThresholdMs: Int = 1_000) {
            self.captureBodies = captureBodies
            self.maxBodyBytes = maxBodyBytes
            self.redactHeaders = redactHeaders
            self.redactJsonFields = redactJsonFields
            self.redactQueryParams = redactQueryParams
            self.streamContentTypes = streamContentTypes
            self.slowRequestThresholdMs = slowRequestThresholdMs
        }
    }
}
