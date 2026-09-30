import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Watches the touches of one window for the recording and never recognises, so the app receives every touch
/// unchanged and no other gesture waits for it. Replaces swizzling `UIWindow.sendEvent`.
final class RecordingTouchRecognizer: UIGestureRecognizer {
    private let onTouches: (Set<UITouch>, UIWindow) -> Void

    init(onTouches: @escaping (Set<UITouch>, UIWindow) -> Void) {
        self.onTouches = onTouches
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    private func report(_ touches: Set<UITouch>) {
        if let window = view as? UIWindow {
            onTouches(touches, window)
        }
    }
}
