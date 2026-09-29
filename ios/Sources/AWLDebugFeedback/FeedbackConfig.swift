//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// Everything the feedback tool needs from the host app.
public struct FeedbackConfig: Sendable {
    /// Base URL of the feedback service; reports go to `{endpoint}/v1/feedback`.
    public let endpoint: URL
    /// Routing key of the app, sent as `X-App-Key`.
    public let appKey: String
    public let appVersion: String
    public let buildNumber: String
    /// Free-form build environment, e.g. `staging` or `prod`.
    public let environment: String
    /// Read when a report is sent. The `screen` entry, if present, fills the report's current screen.
    public let extraMetadata: @MainActor @Sendable () -> [String: String]
    /// Gestures that start a report. A trigger also set in `AWLDebugConfig.triggers` starts feedback only.
    public let triggers: Set<FeedbackTrigger>
    /// How the build is distributed. Only sent when set: older feedback services reject the key.
    public let distribution: AWLDistribution?
    /// Who reports. Only sent when set: older feedback services reject the key.
    public let reporter: FeedbackReporter?
    /// Initial state of "Attach logs". The switch only shows when `AWLDebugTool` is started in the app.
    public let attachLogsByDefault: Bool

    public init(
        endpoint: URL,
        appKey: String,
        appVersion: String,
        buildNumber: String,
        environment: String,
        extraMetadata: @escaping @MainActor @Sendable () -> [String: String] = { [:] },
        triggers: Set<FeedbackTrigger> = [.shake, .screenshot],
        distribution: AWLDistribution? = nil,
        reporter: FeedbackReporter? = nil,
        attachLogsByDefault: Bool = true
    ) {
        self.endpoint = endpoint
        self.appKey = appKey
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.environment = environment
        self.extraMetadata = extraMetadata
        self.triggers = triggers
        self.distribution = distribution
        self.reporter = reporter
        self.attachLogsByDefault = attachLogsByDefault
    }

    @available(*, deprecated, message: "Use triggers: shakeToReport false is triggers: [.screenshot].")
    public init(
        endpoint: URL,
        appKey: String,
        appVersion: String,
        buildNumber: String,
        environment: String,
        extraMetadata: @escaping @MainActor @Sendable () -> [String: String] = { [:] },
        shakeToReport: Bool,
        distribution: AWLDistribution? = nil,
        reporter: FeedbackReporter? = nil,
        attachLogsByDefault: Bool = true
    ) {
        self.init(endpoint: endpoint, appKey: appKey, appVersion: appVersion, buildNumber: buildNumber,
                  environment: environment, extraMetadata: extraMetadata,
                  triggers: shakeToReport ? [.shake, .screenshot] : [.screenshot],
                  distribution: distribution, reporter: reporter, attachLogsByDefault: attachLogsByDefault)
    }

    @available(*, deprecated, message: "Use triggers.contains(.shake).")
    public var shakeToReport: Bool {
        triggers.contains(.shake)
    }
}

/// Gestures that start a report, see `FeedbackConfig.triggers`.
public enum FeedbackTrigger: String, Hashable, CaseIterable, Sendable {
    /// The tester shakes the device (Simulator: Device → Shake).
    case shake
    /// The tester takes a system screenshot.
    case screenshot
}

/// How a build reaches its users.
public enum AWLDistribution: String, Encodable, Sendable {
    /// Local developer build.
    case debug
    /// Test distribution such as TestFlight.
    case `internal`
    /// Public App Store build. The feedback service rejects reports from these.
    case store
}

/// The person filing a report.
public struct FeedbackReporter: Equatable, Sendable {
    public let name: String
    public let email: String?

    public init(name: String, email: String? = nil) {
        self.name = name
        self.email = email
    }
}
