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
        /// Kept on the device and sent later.
        case queued
        case failed(String)
    }

    static let maxTextLength = 5000
    /// Shorter arrow or redact drags are slips: nothing but an arrowhead or a speck.
    private static let minDragLength: CGFloat = 0.02

    let screenshot: UIImage
    /// Oldest first; undo removes the last one whatever its kind.
    @Published private(set) var marks: [MarkupMark] = []
    /// The mark being drawn, shown live and added to `marks` when the gesture ends.
    @Published private(set) var pendingMark: MarkupMark?
    @Published var tool = MarkupTool.pen
    @Published var color = MarkupColor.red
    @Published var text = ""
    @Published private(set) var phase = Phase.editing
    /// Adds `logs.txt` with the debug tool's logs and requests.
    @Published var attachLogs: Bool
    @Published var reporterName: String
    @Published var reporterEmail: String
    /// Name and email fields instead of "Sent as": until a first report is sent, or after "Change".
    @Published private(set) var isEditingReporter: Bool
    let dictation = Dictation()

    private var dictationPrefix = ""
    private let config: FeedbackConfig
    private let queue: FeedbackQueueRunner
    private let logsSource: LogsAttachment.Source?
    private let reporterStore: ReporterStore
    /// The same for every attempt of this report, so the service can drop duplicates.
    private let idempotencyKey = UUID()
    private var dictationChanges: AnyCancellable?

    init(
        screenshot: UIImage,
        config: FeedbackConfig,
        queue: FeedbackQueueRunner = .shared,
        logsSource: LogsAttachment.Source? = LogsAttachment.toolSource,
        reporterStore: ReporterStore = ReporterStore()
    ) {
        self.screenshot = screenshot
        self.config = config
        self.queue = queue
        self.logsSource = logsSource
        self.reporterStore = reporterStore
        attachLogs = config.attachLogsByDefault
        let reporter = reporterStore.load(fallback: config.reporter)
        reporterName = reporter?.name ?? ""
        reporterEmail = reporter?.email ?? ""
        isEditingReporter = reporter == nil
        // Views observe the session only, so dictation state changes are passed on.
        dictationChanges = dictation.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// Only with the debug tool in the app.
    var canAttachLogs: Bool {
        logsSource != nil
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !trimmedText.isEmpty && text.count <= Self.maxTextLength && isReporterValid && !isFinished && phase != .sending
    }

    /// An empty email is fine; one the service would reject is not.
    var isReporterEmailValid: Bool {
        reporterEmail.isBlank || FeedbackMetadata.isValidEmail(reporterEmail.trimmed)
    }

    var isReporterValid: Bool {
        !reporterName.isBlank && isReporterEmailValid
    }

    func changeReporter() {
        isEditingReporter = true
    }

    /// Sent or queued: nothing left to do in the form.
    var isFinished: Bool {
        phase == .sent || phase == .queued
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
        case let .redact(start, _):
            pendingMark?.shape = .redact(start: start, end: point)
        case nil:
            let shape: MarkupMark.Shape = switch tool {
            case .pen: .stroke([point])
            case .arrow: .arrow(start: point, end: point)
            case .redact: .redact(start: point, end: point)
            }
            pendingMark = MarkupMark(shape: shape, color: tool == .redact ? .black : color)
        }
    }

    func endMark() {
        defer { pendingMark = nil }
        guard let mark = pendingMark else {
            return
        }
        switch mark.shape {
        case let .arrow(start, end), let .redact(start, end):
            if hypot(end.x - start.x, end.y - start.y) < Self.minDragLength {
                return
            }
        case .stroke:
            break
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
        let reporter = FeedbackReporter(name: reporterName.trimmed, email: reporterEmail.isBlank ? nil : reporterEmail.trimmed)
        if isEditingReporter {
            reporterStore.save(reporter)
            isEditingReporter = false
        }

        let now = Date.now
        let metadata = FeedbackMetadata(
            osVersion: DeviceInfo.osVersion,
            deviceModel: DeviceInfo.modelIdentifier,
            appVersion: config.appVersion,
            buildNumber: config.buildNumber,
            environment: config.environment,
            locale: FeedbackMetadata.localeIdentifier(.current),
            extraMetadata: config.extraMetadata(),
            date: now,
            distribution: config.distribution,
            reporter: reporter
        )
        let logs = attachLogs ? await LogsAttachment.capture(
            header: LogsAttachment.header(
                config: config,
                device: ["\(metadata.platform) \(metadata.osVersion)", metadata.deviceModel, metadata.locale],
                generatedAt: now,
                timeZone: .current
            ),
            source: logsSource
        ) : nil
        let marked = ScreenshotRenderer.flatten(screenshot: screenshot, marks: marks)
        guard let jpeg = ScreenshotRenderer.jpegData(from: marked) else {
            phase = .failed(FeedbackError.encodingFailed.message)
            return
        }

        let client = FeedbackClient(endpoint: config.endpoint, appKey: config.appKey)
        let request: URLRequest
        do {
            request = try client.makeRequest(
                text: trimmedText,
                metadata: metadata,
                screenshotJPEG: jpeg,
                logs: logs,
                idempotencyKey: idempotencyKey
            )
        } catch {
            phase = .failed(FeedbackError.encodingFailed.message)
            return
        }
        switch await queue.submit(request) {
        case .sent:
            phase = .sent
        case .queued:
            phase = .queued
        case let .failed(error):
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
