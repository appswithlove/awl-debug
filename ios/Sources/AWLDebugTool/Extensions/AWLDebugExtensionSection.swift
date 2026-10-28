import Combine
import Foundation

/// Rows another module adds to the panel's start page, below App Info. Register it with
/// `AWLDebugExtensions.register(_:)`; changes to `items` and `claimedTriggers` show right away.
@MainActor
public final class AWLDebugExtensionSection: ObservableObject, Identifiable {
    public nonisolated let id: String
    /// Sections are sorted by `order`, then by registration.
    public nonisolated let order: Int
    /// The rows, top to bottom. The section is hidden while it has none.
    @Published public var items: [AWLDebugExtensionItem]
    /// Triggers the module handles itself. They no longer open the panel; the panel logs a warning when
    /// `AWLDebugConfig.triggers` has one of them.
    @Published public var claimedTriggers: Set<AWLDebugTrigger>

    public init(id: String, order: Int = 0, items: [AWLDebugExtensionItem] = [], claimedTriggers: Set<AWLDebugTrigger> = []) {
        self.id = id
        self.order = order
        self.items = items
        self.claimedTriggers = claimedTriggers
    }
}

/// A row of an `AWLDebugExtensionSection`, drawn in the panel's own style. Callbacks run on the main actor.
public enum AWLDebugExtensionItem {
    /// Bold text, with an optional button at the trailing edge.
    case title(String, action: AWLDebugExtensionAction? = nil)
    /// Text in `style`. With `copyValue`, tapping the row copies it.
    case text(String, style: AWLDebugTextStyle = .secondary, copyValue: String? = nil)
    /// A switch. `onChange` gets the new value; update `isOn` in `items` to keep it.
    case toggle(String, isOn: Bool, onChange: @MainActor (Bool) -> Void)
    /// A button row with an optional second line. The panel closes first, then `action` runs.
    case link(String, badge: String? = nil, action: @MainActor () -> Void)
}

/// The button of a `.title` row.
public struct AWLDebugExtensionAction {
    public let title: String
    public let isEnabled: Bool
    public let action: @MainActor () -> Void

    public init(_ title: String, isEnabled: Bool = true, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// How a `.text` row looks.
public enum AWLDebugTextStyle: Sendable {
    /// Body text.
    case primary
    /// Smaller, secondary text.
    case secondary
    /// Smaller text in the panel's error colour.
    case error
    /// Smaller monospaced text, e.g. for identifiers.
    case monospace
}

/// Returned by `AWLDebugExtensions.register(_:)` and `observeNetwork(_:)`. Keep it as long as the section or
/// the observer should stay; nothing is removed when it is released.
public final class AWLDebugRegistration: @unchecked Sendable {
    private let lock = NSLock()
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// Removes the section or the observer. Calling it again does nothing.
    public func cancel() {
        lock.lock()
        let onCancel = onCancel
        self.onCancel = nil
        lock.unlock()
        onCancel?()
    }
}

/// The registered sections in panel order.
@MainActor
final class ExtensionSectionRegistry: ObservableObject {
    static let shared = ExtensionSectionRegistry()

    @Published private(set) var sections: [AWLDebugExtensionSection] = []
    private var entries: [(section: AWLDebugExtensionSection, sequence: Int)] = []
    private var nextSequence = 0

    /// Triggers claimed by any registered section.
    var claimedTriggers: Set<AWLDebugTrigger> {
        sections.reduce(into: []) { $0.formUnion($1.claimedTriggers) }
    }

    /// A section with the same `id` is replaced.
    func add(_ section: AWLDebugExtensionSection) {
        entries.removeAll { $0.section.id == section.id || $0.section === section }
        entries.append((section, nextSequence))
        nextSequence += 1
        entries.sort { ($0.section.order, $0.sequence) < ($1.section.order, $1.sequence) }
        sections = entries.map(\.section)
    }

    /// Removes this very section; a newer one with the same `id` stays.
    func remove(_ section: AWLDebugExtensionSection) {
        guard entries.contains(where: { $0.section === section }) else {
            return
        }
        entries.removeAll { $0.section === section }
        sections = entries.map(\.section)
    }
}
