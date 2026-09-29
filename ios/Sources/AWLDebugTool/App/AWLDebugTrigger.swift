import ObjectiveC
import UIKit

/// Gestures and events that open the debug panel, see `AWLDebugConfig.triggers`.
public enum AWLDebugTrigger: Hashable, CaseIterable {
    /// Three fingers tap at once. In the Simulator two fingers (hold Option).
    case threeFingerTap
    /// Three quick taps with one finger.
    case tripleTap
    /// The tester takes a system screenshot.
    case screenshot
    /// The tester shakes the device (Simulator: Device → Shake).
    case shake

    /// Names used by AWLDebugFeedback to announce the triggers it handles, see `DebugPanelPresenter.feedbackTriggersNotification`.
    init?(feedbackName: String) {
        switch feedbackName {
        case "screenshot": self = .screenshot
        case "shake": self = .shake
        default: return nil
        }
    }
}

public extension AWLDebugTool {
    /// Whether gestures open the panel on this device; stored per device and kept by "Clear App Data".
    /// Defaults to `true`. Ignored with `AWLDebugConfig.isAlwaysActive`; `open()` always works.
    static var isActivated: Bool {
        get { UserDefaults.standard.object(forKey: Constants.UserDefaultsKey.isActivated) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Constants.UserDefaultsKey.isActivated) }
    }
}

/// Reports device shakes as a notification by chaining `motionEnded` on `UIWindow`, so the host app
/// needs no window subclass. Installed only when `.shake` is configured.
enum PanelShakeDetector {
    static let notification = Notification.Name("AWLDebugDeviceDidShake")

    private typealias MotionIMP = @convention(c) (UIWindow, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
    private typealias MotionBlock = @convention(block) (UIWindow, UIEvent.EventSubtype, UIEvent?) -> Void

    @MainActor private static var isInstalled = false

    @MainActor
    static func install() {
        guard !isInstalled else {
            return
        }
        isInstalled = true

        let selector = #selector(UIResponder.motionEnded(_:with:))
        guard let inherited = class_getInstanceMethod(UIWindow.self, selector) else {
            return
        }
        let original = unsafeBitCast(method_getImplementation(inherited), to: MotionIMP.self)
        let block: MotionBlock = { window, motion, event in
            if motion == .motionShake {
                NotificationCenter.default.post(name: notification, object: window)
            }
            original(window, selector, motion, event)
        }
        let replacement = imp_implementationWithBlock(block)
        if !class_addMethod(UIWindow.self, selector, replacement, method_getTypeEncoding(inherited)) {
            method_setImplementation(inherited, replacement)
        }
    }
}
