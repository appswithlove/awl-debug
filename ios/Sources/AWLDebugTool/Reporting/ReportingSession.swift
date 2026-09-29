import Foundation

/// Session object of a batch, stored in the buffer next to its entries.
struct ReportingSession: Codable, Equatable {
    static let sdkVersion = "2.0.0"

    let id: String
    var userIdentifier: String?
    let startedAtMillis: Int64
    var endedAtMillis: Int64?
    let appVersion: String
    let buildNumber: String
    let environment: String
    let distribution: String
    let sdkVersion: String
    let deviceModel: String
    let osVersion: String
    let locale: String?
    let totalRamBytes: UInt64?

    static func create(config: RemoteReportingConfig, userIdentifier: String?, nowMillis: Int64) -> ReportingSession {
        let info = Bundle.main.infoDictionary ?? [:]
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return ReportingSession(
            id: UUID().uuidString.lowercased(),
            userIdentifier: userIdentifier,
            startedAtMillis: nowMillis,
            endedAtMillis: nil,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: info["CFBundleVersion"] as? String ?? "",
            environment: config.environment,
            distribution: config.distribution.rawValue,
            sdkVersion: sdkVersion,
            deviceModel: modelIdentifier,
            osVersion: os.patchVersion > 0 ? "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)" : "\(os.majorVersion).\(os.minorVersion)",
            locale: Locale.current.identifier(.bcp47),
            totalRamBytes: ProcessInfo.processInfo.physicalMemory
        )
    }

    /// Hardware identifier such as `iPhone17,1`; on the simulator the simulated device's.
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }
}
