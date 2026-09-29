import Foundation
import UIKit

/// Process-wide entry point behind `AWLDebugConfig.remoteReporting`.
final class RemoteReporting {
    enum Status: Equatable {
        case notConfigured
        /// `distribution` is `.store` or the app has an App Store receipt.
        case storeBuild
        case recording
    }

    static let shared = RemoteReporting()

    private let lock = NSLock()
    private var _reporter: RemoteReporter?
    private var _status = Status.notConfigured
    private var appUserId: String?
    private var observers: [NSObjectProtocol] = []

    var reporter: RemoteReporter? {
        lock.lock()
        defer { lock.unlock() }
        return _reporter
    }

    var status: Status {
        lock.lock()
        defer { lock.unlock() }
        return _status
    }

    /// `Library/Application Support/AWLDebug/reporting/`
    static var bufferDirectory: URL {
        let library = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("AWLDebug/reporting", isDirectory: true)
    }

    /// App Store installs have a `receipt` and no provisioning profile. TestFlight builds have a `sandboxReceipt`;
    /// development, ad hoc and enterprise builds carry `embedded.mobileprovision` (the simulator reports `receipt`, too).
    static var hasAppStoreReceipt: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "receipt"
            && Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") == nil
        #endif
    }

    func start(config: RemoteReportingConfig?, directory: URL = RemoteReporting.bufferDirectory) {
        lock.lock()
        defer { lock.unlock() }
        guard _reporter == nil, let config else { return }
        guard config.distribution != .store, !Self.hasAppStoreReceipt else {
            _status = .storeBuild
            print("\(LS.logWatermark) Remote reporting is off in store builds.")
            return
        }
        guard !config.appKey.isEmpty, config.endpoint.scheme?.hasPrefix("http") == true else {
            print("\(LS.logWatermark) Remote reporting needs an http(s) endpoint and an app key.")
            return
        }
        let reporter = RemoteReporter(config: config, buffer: ReportingBuffer(root: directory), appUserId: appUserId)
        _reporter = reporter
        _status = .recording
        reporter.start()
        observeLifecycle(of: reporter)
    }

    func record(_ log: NetworkLog) {
        reporter?.record(log)
    }

    func setUserIdentifier(_ appUserId: String?) {
        lock.lock()
        self.appUserId = appUserId
        let reporter = _reporter
        lock.unlock()
        reporter?.setUserIdentifier(appUserId)
    }

    func flush() {
        reporter?.flush()
    }

    private func observeLifecycle(of reporter: RemoteReporter) {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
                reporter.onForeground()
            },
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
                reporter.onBackground()
            },
        ]
        DispatchQueue.main.async {
            // Started after the app became active: no notification follows.
            if UIApplication.shared.applicationState == .active {
                reporter.onForeground()
            }
        }
    }
}
