import Foundation
import ObjectiveC

/// Reads AWLDebugFeedback through its `AWLFeedbackBridge` class, so this product does not link it.
/// `nil` without AWLDebugFeedback in the app or while no configured `feedbackTool` is on screen.
@MainActor
struct FeedbackBridge {
    static let className = "AWLFeedbackBridge"
    /// Posted by AWLDebugFeedback when availability, triggers or pending count change.
    static let didChangeNotification = Notification.Name("AWLFeedbackBridgeDidChange")

    private let bridge: AnyClass

    static var current: FeedbackBridge? {
        bridge(named: className)
    }

    static func bridge(named name: String) -> FeedbackBridge? {
        guard let bridge = NSClassFromString(name) else {
            return nil
        }
        let result = FeedbackBridge(bridge: bridge)
        return result.bool("isAvailable") == true ? result : nil
    }

    var triggers: Set<AWLDebugTrigger> {
        let selector = NSSelectorFromString("triggers")
        guard (bridge as AnyObject).responds(to: selector),
              let names = (bridge as AnyObject).perform(selector)?.takeUnretainedValue() as? [String] else {
            return []
        }
        return Set(names.compactMap(AWLDebugTrigger.init(feedbackName:)))
    }

    var pendingCount: Int {
        typealias Count = @convention(c) (AnyClass, Selector) -> Int
        return call("pendingCount", as: Count.self)?(bridge, NSSelectorFromString("pendingCount")) ?? 0
    }

    func start() {
        typealias Start = @convention(c) (AnyClass, Selector) -> Void
        call("start", as: Start.self)?(bridge, NSSelectorFromString("start"))
    }

    private func bool(_ selector: String) -> Bool? {
        typealias Getter = @convention(c) (AnyClass, Selector) -> ObjCBool
        return call(selector, as: Getter.self)?(bridge, NSSelectorFromString(selector)).boolValue
    }

    private func call<Function>(_ selector: String, as _: Function.Type) -> Function? {
        guard let method = class_getClassMethod(bridge, NSSelectorFromString(selector)) else {
            return nil
        }
        return unsafeBitCast(method_getImplementation(method), to: Function.self)
    }
}
