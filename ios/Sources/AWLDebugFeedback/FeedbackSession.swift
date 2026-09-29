//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Combine
import UIKit

/// One report from capture to sent.
@MainActor
final class FeedbackSession: ObservableObject {
    enum Phase: Equatable {
        case editing
        case sending
        case sent
        case failed(String)
    }

    static let maxTextLength = 5000
    /// Shorter drags would draw nothing but an arrowhead.
    private static let minArrowLength: CGFloat = 0.02

    let screenshot: UIImage
    /// Oldest first; undo removes the last one whatever its kind.
    @Published private(set) var marks: [MarkupMark] = []
    /// The mark being drawn, shown live and added to `marks` when the gesture ends.
    @Published private(set) var pendingMark: MarkupMark?
    @Published var tool = MarkupTool.pen
    @Published var color = MarkupColor.red
    @Published var text = ""
    @Published private(set) var phase = Phase.editing
    let dictation = Dictation()

    private var dictationPrefix = ""
    private let config: FeedbackConfig
    private var dictationChanges: AnyCancellable?

    init(screenshot: UIImage, config: FeedbackConfig) {
        self.screenshot = screenshot
        self.config = config
        // Views observe the session only, so dictation state changes are passed on.
        dictationChanges = dictation.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !trimmedText.isEmpty && text.count <= Self.maxTextLength && phase != .sending && phase != .sent
    }

    var canUndo: Bool {
        !marks.isEmpty && phase == .editing
    }

    func undoLastMark() {
        guard canUndo else {
            return
        }
        marks.removeLast()
    }

    func clearMarks() {
        marks.removeAll()
    }

    /// Extends the pending mark to `point`, in unit coordinates of the screenshot.
    func dragMark(to point: CGPoint) {
        let point = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        switch pendingMark?.shape {
        case let .stroke(points):
            pendingMark?.shape = .stroke(points + [point])
        case let .arrow(start, _):
            pendingMark?.shape = .arrow(start: start, end: point)
        case nil:
            let shape: MarkupMark.Shape = switch tool {
            case .pen: .stroke([point])
            case .arrow: .arrow(start: point, end: point)
            }
            pendingMark = MarkupMark(shape: shape, color: color)
        }
    }

    func endMark() {
        defer { pendingMark = nil }
        guard let mark = pendingMark else {
            return
        }
        if case let .arrow(start, end) = mark.shape, hypot(end.x - start.x, end.y - start.y) < Self.minArrowLength {
            return
        }
        marks.append(mark)
    }

    func toggleDictation() async {
        if dictation.isRecording {
            dictation.stop()
            return
        }
        dictationPrefix = text
        await dictation.start { [weak self] transcript in
            self?.applyTranscript(transcript)
        }
    }

    func send() async {
        guard canSend else {
            return
        }
        dictation.stop()
        phase = .sending

        let metadata = FeedbackMetadata(
            osVersion: DeviceInfo.osVersion,
            deviceModel: DeviceInfo.modelIdentifier,
            appVersion: config.appVersion,
            buildNumber: config.buildNumber,
            environment: config.environment,
            locale: FeedbackMetadata.localeIdentifier(.current),
            extraMetadata: config.extraMetadata(),
            date: .now,
            distribution: config.distribution,
            reporter: config.reporter
        )
        let marked = ScreenshotRenderer.flatten(screenshot: screenshot, marks: marks)
        guard let jpeg = ScreenshotRenderer.jpegData(from: marked) else {
            phase = .failed(FeedbackError.encodingFailed.message)
            return
        }

        let client = FeedbackClient(endpoint: config.endpoint, appKey: config.appKey)
        do {
            _ = try await client.send(text: trimmedText, metadata: metadata, screenshotJPEG: jpeg)
            phase = .sent
        } catch {
            phase = .failed(error.message)
        }
    }

    func discard() {
        dictation.stop()
    }

    private func applyTranscript(_ transcript: String) {
        guard !transcript.isEmpty else {
            return
        }
        let separator = dictationPrefix.isEmpty || dictationPrefix.last?.isWhitespace == true ? "" : " "
        text = dictationPrefix + separator + transcript
    }
}
