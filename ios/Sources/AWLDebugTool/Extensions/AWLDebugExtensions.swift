import Foundation

/// Lets another module build on the tool: add rows to the panel, and read the logs, the captured requests and
/// the screen recording. Everything it hands out is already redacted, like in the panel.
///
/// Safe to use before `AWLDebugTool.start`: registrations take effect right away, reads return nothing until
/// the tool is started.
public enum AWLDebugExtensions {
    /// Shows `section` on the panel's start page until the registration is cancelled. A section with the
    /// same `id` is replaced.
    @MainActor @discardableResult
    public static func register(_ section: AWLDebugExtensionSection) -> AWLDebugRegistration {
        ExtensionSectionRegistry.shared.add(section)
        return AWLDebugRegistration { [weak section] in
            guard let section else {
                return
            }
            if Thread.isMainThread {
                MainActor.assumeIsolated { ExtensionSectionRegistry.shared.remove(section) }
            } else {
                Task { @MainActor in ExtensionSectionRegistry.shared.remove(section) }
            }
        }
    }

    /// Calls `handler` for every request the Network module captures from now on, redacted and in the order
    /// they finish, on a background queue. Also works when registered before `AWLDebugTool.start`.
    public static func observeNetwork(_ handler: @escaping @Sendable (AWLDebugNetworkRecord) -> Void) -> AWLDebugRegistration {
        ExtensionState.shared.addNetworkObserver(handler)
    }

    /// `true` once `AWLDebugTool.start` ran.
    public static var isStarted: Bool {
        ExtensionState.shared.isStarted
    }

    /// The newest `maxEntries` entries of the Logs module that pass its level and search filters, oldest
    /// first, after reading new unified-log entries. `nil` before `AWLDebugTool.start`.
    @MainActor
    public static func logSnapshot(maxEntries: Int) async -> AWLDebugLogSnapshot? {
        guard isStarted else {
            return nil
        }
        let store = AWLDebugTool.shared.appLogs
        await store.readOSLog()
        return AWLDebugLogSnapshot(records: store.filteredEntries.suffix(max(maxEntries, 0)).map(AWLDebugLogRecord.init),
                                   levelFilter: AWLDebugLogLevel.allCases.reversed().filter(store.selectedLevels.contains),
                                   searchText: store.searchText)
    }

    /// The newest `maxEntries` requests of the Network module, ordered by start time. Empty before `AWLDebugTool.start`.
    public static func networkSnapshot(maxEntries: Int) -> [AWLDebugNetworkRecord] {
        AWLDebugTool.shared.networkLogger.snapshot(maxEntries: maxEntries).map(AWLDebugNetworkRecord.init)
    }

    /// `true` while screen recording is switched on and the current or the previous run's recording has frames.
    /// Frames left on disk after the tester switched recording off do not count.
    public static var hasRecording: Bool {
        guard ExtensionState.shared.isRecordingOn else {
            return false
        }
        let storage = RecordingStorage()
        return [storage.currentFolder, storage.lastFolder].contains { RecordingStorage.newestFrameDate(in: $0) != nil }
    }

    /// Encodes the current screen recording, or the previous run's while the current one has no frames, off the
    /// main thread. `nil` without a recording or when encoding fails.
    public static func exportRecording(_ options: AWLDebugRecordingExportOptions) async -> AWLDebugRecordingExport? {
        guard let folder = await ScreenRecorder.shared.exportFolder() else {
            return nil
        }
        let frames = RecordingStorage.timedFrames(in: folder)
        let events = RecordingStorage.events(in: folder)
        return await Task.detached(priority: .userInitiated) {
            await RecordingExport.export(frames: frames, events: events, options: options)
        }.value
    }

    /// Closes the panel and returns once it is gone, right away when it is closed. For example before taking a
    /// screenshot of the app.
    @MainActor
    public static func closePanel() async {
        await withCheckedContinuation { continuation in
            DebugPanelPresenter.shared.close {
                continuation.resume()
            }
        }
    }

    /// `request`, marked so that the Network module does not capture it. For a module's own requests.
    public static func excludeFromCapture(_ request: URLRequest) -> URLRequest {
        guard let marked = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.setProperty(true, forKey: AWLDebugURLProtocol.Constants.SkipCaptureKey, in: marked)
        return marked as URLRequest
    }

    /// "Clear App Data" keeps the `UserDefaults.standard` keys that start with `userDefaultsPrefix`,
    /// like the tool's own settings.
    public static func keepOnClearAppData(userDefaultsPrefix: String) {
        ExtensionState.shared.keep(userDefaultsPrefix: userDefaultsPrefix)
    }
}

/// State behind `AWLDebugExtensions` that is read from any thread.
final class ExtensionState: @unchecked Sendable {
    static let shared = ExtensionState()

    private let lock = NSLock()
    private var _isStarted = false
    private var _isRecordingOn = false
    private var keptPrefixes: [String] = []
    private var networkObservers: [UUID: @Sendable (AWLDebugNetworkRecord) -> Void] = [:]
    private let networkQueue = DispatchQueue(label: "com.appswithlove.debug.extensions.network", qos: .utility)

    var isStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isStarted
    }

    func markStarted() {
        lock.lock()
        _isStarted = true
        lock.unlock()
    }

    /// The tester's "Screen recording" switch, kept current by `ScreenRecorderModel`.
    var isRecordingOn: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRecordingOn
    }

    func setRecordingOn(_ isOn: Bool) {
        lock.lock()
        _isRecordingOn = isOn
        lock.unlock()
    }

    var keptUserDefaultsPrefixes: [String] {
        lock.lock()
        defer { lock.unlock() }
        return keptPrefixes
    }

    func keep(userDefaultsPrefix: String) {
        guard !userDefaultsPrefix.isEmpty else {
            return
        }
        lock.lock()
        if !keptPrefixes.contains(userDefaultsPrefix) {
            keptPrefixes.append(userDefaultsPrefix)
        }
        lock.unlock()
    }

    func addNetworkObserver(_ handler: @escaping @Sendable (AWLDebugNetworkRecord) -> Void) -> AWLDebugRegistration {
        let id = UUID()
        lock.lock()
        networkObservers[id] = handler
        lock.unlock()
        return AWLDebugRegistration { [weak self] in
            guard let self else {
                return
            }
            self.lock.lock()
            self.networkObservers[id] = nil
            self.lock.unlock()
        }
    }

    /// Hands a captured request to the observers, in capture order.
    func publish(_ log: NetworkLog) {
        lock.lock()
        let hasObservers = !networkObservers.isEmpty
        lock.unlock()
        guard hasObservers else {
            return
        }
        let record = AWLDebugNetworkRecord(log)
        networkQueue.async { [self] in
            lock.lock()
            let observers = Array(networkObservers.values)
            lock.unlock()
            for observer in observers {
                observer(record)
            }
        }
    }
}
