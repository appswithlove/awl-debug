//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import ObjectiveC
import UIKit

/// Reports device shakes as a notification.
///
/// Shake events travel up the responder chain to the key window. Instead of requiring a window
/// subclass from the host app, `motionEnded` on `UIWindow` is chained at runtime — and only once
/// the tool is actually enabled, so a build that never enables it keeps UIKit's behaviour.
enum ShakeDetector {
    static let notification = Notification.Name("AWLFeedbackDeviceDidShake")

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
