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
