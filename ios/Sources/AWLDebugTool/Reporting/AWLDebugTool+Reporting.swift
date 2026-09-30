import Foundation

public extension AWLDebugTool {
    /// Identifies the signed-in user in remote reporting; `nil` after logout. Only a SHA-256 hash of
    /// `appKey:appUserId` leaves the device. Can be called before `start(config:)`.
    static func setUserIdentifier(_ appUserId: String?) {
        RemoteReporting.shared.setUserIdentifier(appUserId)
    }

    /// Packs everything recorded for remote reporting so far into batches and sends them right away.
    static func flushReports() {
        RemoteReporting.shared.flush()
    }
}
