import UIKit

/// Records the app's own windows as JPEG frames, 3 per second and only while something happens. On the main thread it
/// only draws the windows and finds the masked areas; masks, touch circles, encoding and file access run in the
/// background. A frame is skipped while the previous one is still being encoded.
@MainActor
final class ScreenRecorder: NSObject {
    static let shared = ScreenRecorder()
    nonisolated static let framesPerSecond = 3

    let storage: RecordingStorage
    private let encodingQueue = DispatchQueue(label: "com.appswithlove.debug.recording", qos: .utility)
    private var didRotate = false
    private var timer: Timer?
    private var activity = RecordingActivity()
    private var touches: [ObjectIdentifier: RecordingTouch] = [:]
    private var isEncoding = false
    private var maxFrames = 300 * framesPerSecond
    private var isLandscape: Bool?
    private var recognizers: [ObjectIdentifier: (window: Weak<UIWindow>, recognizer: RecordingTouchRecognizer)] = [:]

    /// `true` while the panel is open; no frames are taken then.
    var isPaused = false

    var isRunning: Bool {
        timer != nil
    }

    init(storage: RecordingStorage = RecordingStorage()) {
        self.storage = storage
        super.init()
    }

    /// Moves the previous run's recording to `last`. Only the first call per process does something.
    func rotateOnce() {
        guard !didRotate else {
            return
        }
        didRotate = true
        encodingQueue.sync {
            storage.rotate()
        }
    }

    func start(maxDurationSeconds: Int) {
        rotateOnce()
        maxFrames = max(1, maxDurationSeconds) * Self.framesPerSecond
        guard timer == nil else {
            return
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowDidBecomeVisible(_:)), name: UIWindow.didBecomeVisibleNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
        center.addObserver(self, selector: #selector(noteActivity), name: UIDevice.orientationDidChangeNotification, object: nil)
        // Typing: the keyboard's own window is not watched for touches.
        center.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextView.textDidChangeNotification, object: nil)
        installRecognizers()
        activity = RecordingActivity()
        activity.noteActivity(at: Date())
        let timer = Timer(timeInterval: 1 / TimeInterval(Self.framesPerSecond), target: self,
                          selector: #selector(tick), userInfo: nil, repeats: true)
        // `.common`, so frames are also taken while a scroll view tracks a finger.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        touches = [:]
        isLandscape = nil
        NotificationCenter.default.removeObserver(self)
        for entry in recognizers.values {
            entry.window.value?.removeGestureRecognizer(entry.recognizer)
        }
        recognizers = [:]
    }

    // MARK: - Frames

    @objc private func tick() {
        guard !isPaused, !isEncoding, UIApplication.shared.applicationState != .background else {
            return
        }
        let now = Date()
        let isTouching = touches.values.contains { $0.phase != .ended }
        guard activity.shouldCapture(at: now, isTouching: isTouching), let scene = Self.activeScene() else {
            return
        }
        let windows = RecordingFrameRenderer.appWindows(of: scene)
        guard !windows.isEmpty,
              let frame = RecordingFrameRenderer.capture(windows: windows, bounds: scene.screen.bounds, date: now) else {
            return
        }
        noteOrientation(of: scene, at: now)
        let drawnTouches = Array(touches.values)
        touches = touches.filter { $0.value.phase != .ended }

        isEncoding = true
        let storage = storage
        let maxFrames = maxFrames
        encodingQueue.async { [weak self] in
            if let jpeg = RecordingFrameRenderer.encode(frame, touches: drawnTouches) {
                storage.write(jpeg, capturedAt: frame.date, maxFrames: maxFrames)
            }
            DispatchQueue.main.async {
                self?.isEncoding = false
            }
        }
    }

    /// Waits until frames queued for encoding are on disk.
    func waitForPendingFrames() {
        encodingQueue.sync {}
    }

    // MARK: - Touches and activity

    @objc private func noteActivity() {
        activity.noteActivity(at: Date())
    }

    @objc private func textDidChange(_ notification: Notification) {
        if Self.isTypingInApp(notification) {
            noteActivity()
        }
    }

    /// Typing in an app window. Typing in the SDK's own windows (e.g. the feedback form) is not the app being used,
    /// so it takes no frames of the screen below.
    static func isTypingInApp(_ notification: Notification) -> Bool {
        guard let window = (notification.object as? UIView)?.window else {
            return false
        }
        return RecordingFrameRenderer.isAppWindow(window)
    }

    @objc private func keyboardWillShow() {
        noteEvent("keyboard shown")
    }

    @objc private func keyboardDidHide() {
        noteEvent("keyboard hidden")
    }

    private func noteEvent(_ text: String, at date: Date = Date()) {
        activity.noteActivity(at: date)
        guard !isPaused else {
            return
        }
        let storage = storage
        encodingQueue.async {
            storage.appendEvent(text, at: date)
        }
    }

    /// Adds an `orientation` event when the screen turned since the last frame.
    private func noteOrientation(of scene: UIWindowScene, at date: Date) {
        let bounds = scene.screen.bounds
        let landscape = bounds.width > bounds.height
        defer { isLandscape = landscape }
        if let isLandscape, isLandscape != landscape {
            noteEvent("orientation \(landscape ? "landscape" : "portrait")", at: date)
        }
    }

    private func record(_ touches: Set<UITouch>, in window: UIWindow) {
        guard !isPaused else {
            return
        }
        let now = Date()
        let screen = window.windowScene?.screen.bounds.size ?? window.bounds.size
        for touch in touches {
            let point = touch.location(in: window)
            let location = CGPoint(x: point.x + window.frame.minX, y: point.y + window.frame.minY)
            let phase: RecordingTouchPhase
            switch touch.phase {
            case .began: phase = .began
            case .ended, .cancelled: phase = .ended
            default: phase = .moved
            }
            self.touches[ObjectIdentifier(touch)] = RecordingTouch(location: location, phase: phase)
            if phase != .moved {
                noteEvent(RecordingTimeline.touchEvent(phase: phase, at: location, in: screen), at: now)
            }
        }
        activity.noteActivity(at: now)
    }

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        if let window = notification.object as? UIWindow {
            install(on: window)
        }
    }

    private func installRecognizers() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        scenes.flatMap(\.windows).forEach(install(on:))
    }

    private func install(on window: UIWindow) {
        let id = ObjectIdentifier(window)
        guard RecordingFrameRenderer.isAppWindow(window), recognizers[id]?.window.value !== window else {
            return
        }
        let recognizer = RecordingTouchRecognizer { [weak self] touches, window in
            self?.record(touches, in: window)
        }
        window.addGestureRecognizer(recognizer)
        recognizers[id] = (Weak(window), recognizer)
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

// MARK: - Export

extension ScreenRecorder {
    /// Builds `recording.mp4`, `frames.jpg` and `timeline.md` from all frames of `folder` and offers them as a ZIP in
    /// the share sheet. `false` when there are no frames.
    func exportZip(folder: URL, completion: @escaping (Bool) -> Void) {
        waitForPendingFrames()
        let frames = RecordingStorage.timedFrames(in: folder)
        guard !frames.isEmpty else {
            completion(false)
            return
        }
        let events = RecordingStorage.events(in: folder)
        Task.detached(priority: .userInitiated) {
            let zip = try? await RecordingExport.zip(frames: frames, events: events, date: .now)
            await MainActor.run {
                if let zip {
                    let activity = UIActivityViewController(activityItems: [zip], applicationActivities: nil)
                    UIViewController.topMostViewController()?.present(activity, animated: true)
                }
                completion(true)
            }
        }
    }

    /// Current recording, or the previous run's when the current one has no frames yet. Waits for pending frames.
    func feedbackRecordingFolder() -> URL? {
        waitForPendingFrames()
        return [storage.currentFolder, storage.lastFolder].first { RecordingStorage.newestFrameDate(in: $0) != nil }
    }
}

private final class Weak<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value) {
        self.value = value
    }
}
