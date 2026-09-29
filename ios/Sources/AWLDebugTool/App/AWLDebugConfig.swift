import Foundation

/// Options passed to `AWLDebugTool.start(config:)`.
public struct AWLDebugConfig {
    public var network: NetworkConfig

    public init(network: NetworkConfig = NetworkConfig()) {
        self.network = network
    }

    public struct NetworkConfig {
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
        /// Query parameter names whose values are redacted.
        public var redactQueryParams: Set<String>
        /// Request and response content types whose bodies are never read, in addition to
        /// `text/event-stream` and `application/x-ndjson`. Responses with status 101 are never read either.
        public var streamContentTypes: Set<String>
        /// Requests slower than this are labelled "slow" in the list.
        public var slowRequestThresholdMs: Int

        public init(captureBodies: Bool = true,
                    maxBodyBytes: Int = 256 * 1024,
                    redactHeaders: Set<String> = [],
                    redactJsonFields: Set<String> = ["password", "accessToken", "refreshToken", "idToken", "clientSecret"],
                    redactQueryParams: Set<String> = ["access_token", "token", "api_key"],
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
