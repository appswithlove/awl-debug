import Foundation

/// Frames are only taken while something happens: up to one second after a touch, typing, a keyboard or orientation
/// change, while a finger is down, and two more frames after that so the screen's reaction is in the recording.
struct RecordingActivity {
    static let activeInterval: TimeInterval = 1
    static let framesAfterActivity = 2

    private var lastActivity: Date?
    private var framesSinceActive = framesAfterActivity

    mutating func noteActivity(at date: Date) {
        lastActivity = date
        framesSinceActive = 0
    }

    /// Whether the tick at `date` takes a frame; counts the trailing frames.
    mutating func shouldCapture(at date: Date, isTouching: Bool) -> Bool {
        if isTouching {
            noteActivity(at: date)
        }
        if let lastActivity, date.timeIntervalSince(lastActivity) < Self.activeInterval {
            return true
        }
        guard framesSinceActive < Self.framesAfterActivity else {
            return false
        }
        framesSinceActive += 1
        return true
    }
}

/// Keyboard rows for the timeline: one per change, and only for the app's keyboard. UIKit can report the keyboard
/// showing or hiding twice in a row, and the keyboard of the SDK's own windows (e.g. the feedback form) is not the app
/// being used, so it takes no frames either.
struct RecordingKeyboard {
    /// `true` while the keyboard is up for the app, `false` while it is up for an SDK window, `nil` while it is hidden.
    private var isUpForApp: Bool?

    /// The row for the keyboard about to show, if any.
    mutating func willShow(forApp: Bool) -> String? {
        defer { isUpForApp = forApp }
        return forApp && isUpForApp != true ? "keyboard shown" : nil
    }

    /// The row for the keyboard that was hidden, if any.
    mutating func didHide() -> String? {
        defer { isUpForApp = nil }
        return isUpForApp == true ? "keyboard hidden" : nil
    }
}
