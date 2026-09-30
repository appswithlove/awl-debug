import Foundation

/// Sends sessions, captured requests and performance samples to the feedback service.
/// Set it in `AWLDebugConfig.remoteReporting`.
public struct RemoteReportingConfig {
    /// How the build is distributed. With `.store` nothing is recorded or sent.
    public enum Distribution: String, Sendable {
        /// Local developer build.
        case debug
        /// Test distribution such as TestFlight.
        case `internal`
        /// Public App Store build. The debug SDK must not be part of it at all.
        case store
    }

    /// Base URL of the feedback service, e.g. `https://feedback.example.ch`.
    public var endpoint: URL
    /// App key of the feedback service (`fbk_…`), the same as for feedback.
    public var appKey: String
    /// Free-form backend name such as `staging` or `prod`.
    public var environment: String
    public var distribution: Distribution
    /// Also sends captured request and response bodies. Needs `AWLDebugConfig.network.captureBodies`.
    public var captureBodies: Bool
    /// Bodies are cut off after this many bytes, at most 65536.
    public var maxBodyBytes: Int
    /// Only sends over networks that are not expensive or constrained.
    public var onlyOnUnmeteredNetwork: Bool

    public init(endpoint: URL,
                appKey: String,
                environment: String,
                distribution: Distribution,
                captureBodies: Bool = false,
                maxBodyBytes: Int = 64 * 1024,
                onlyOnUnmeteredNetwork: Bool = false) {
        self.endpoint = endpoint
        self.appKey = appKey
        self.environment = environment
        self.distribution = distribution
        self.captureBodies = captureBodies
        self.maxBodyBytes = maxBodyBytes
        self.onlyOnUnmeteredNetwork = onlyOnUnmeteredNetwork
    }
}
