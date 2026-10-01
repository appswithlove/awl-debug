//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation
import ObjectiveC

/// Calls into `AWLDebugTool` through its `AWLDebugToolBridge` class, if the app has the tool.
enum ToolBridge {
    static let className = "AWLDebugToolBridge"

    /// Closes the debug panel so it is not in the screenshot, then calls `completion` on the main thread.
    /// Calls `completion` right away without the tool or with an older tool.
    @MainActor
    static func closePanel(_ completion: @escaping @MainActor () -> Void) {
        typealias ClosePanel = @convention(c) (AnyClass, Selector, @escaping @convention(block) () -> Void) -> Void
        let selector = "closePanel:"
        guard let bridge = NSClassFromString(className),
              let closePanel = classMethod(of: bridge, selector, as: ClosePanel.self) else {
            completion()
            return
        }
        closePanel(bridge, NSSelectorFromString(selector)) {
            Task { @MainActor in completion() }
        }
    }

    static func classMethod<Function>(of type: AnyClass, _ selector: String, as _: Function.Type) -> Function? {
        guard let method = class_getClassMethod(type, NSSelectorFromString(selector)) else {
            return nil
        }
        return unsafeBitCast(method_getImplementation(method), to: Function.self)
    }
}
