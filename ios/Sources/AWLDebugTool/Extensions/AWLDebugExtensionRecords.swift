import Foundation

/// Entries of the Logs module, as returned by `AWLDebugExtensions.logSnapshot(maxEntries:)`.
public struct AWLDebugLogSnapshot: Sendable {
    /// The newest entries that pass the module's filters, oldest first. Already redacted.
    public let records: [AWLDebugLogRecord]
    /// Levels selected in the module, most severe first. Empty when every level is shown.
    public let levelFilter: [AWLDebugLogLevel]
    /// Search text of the module, empty without a search.
    public let searchText: String

    public init(records: [AWLDebugLogRecord], levelFilter: [AWLDebugLogLevel], searchText: String) {
        self.records = records
        self.levelFilter = levelFilter
        self.searchText = searchText
    }
}

/// One entry of the Logs module.
public struct AWLDebugLogRecord: Sendable {
    public let date: Date
    public let level: AWLDebugLogLevel
    /// Tag, category or subsystem of the entry, `nil` without one.
    public let tag: String?
    public let message: String
    /// Type and description of an attached error.
    public let errorDescription: String?

    public init(date: Date, level: AWLDebugLogLevel, tag: String? = nil, message: String, errorDescription: String? = nil) {
        self.date = date
        self.level = level
        self.tag = tag
        self.message = message
        self.errorDescription = errorDescription
    }
}

/// One request captured by the Network module, already redacted.
public struct AWLDebugNetworkRecord: Sendable {
    /// When the request started.
    public let date: Date
    public let method: String
    public let url: String
    /// HTTP status, `nil` when no response arrived.
    public let statusCode: Int?
    public let durationMs: Int
    /// Header names as sent, sorted case-insensitively.
    public let requestHeaders: [AWLDebugHeader]
    public let responseHeaders: [AWLDebugHeader]
    /// `nil` when bodies are not captured (`AWLDebugConfig.NetworkConfig.captureBodies`) or there was none.
    public let requestBody: AWLDebugNetworkBody?
    public let responseBody: AWLDebugNetworkBody?
    /// Why the request failed: `timeout`, `dns`, `tls`, `cancelled` or `connection`. `nil` when it did not fail
    /// or the app cancelled it.
    public let errorCode: String?
    public let requestBytes: Int
    public let responseBytes: Int

    public init(date: Date,
                method: String,
                url: String,
                statusCode: Int?,
                durationMs: Int,
                requestHeaders: [AWLDebugHeader] = [],
                responseHeaders: [AWLDebugHeader] = [],
                requestBody: AWLDebugNetworkBody? = nil,
                responseBody: AWLDebugNetworkBody? = nil,
                errorCode: String? = nil,
                requestBytes: Int = 0,
                responseBytes: Int = 0) {
        self.date = date
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.requestHeaders = requestHeaders
        self.responseHeaders = responseHeaders
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.errorCode = errorCode
        self.requestBytes = requestBytes
        self.responseBytes = responseBytes
    }
}

public struct AWLDebugHeader: Sendable, Hashable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// A captured body, cut to `AWLDebugConfig.NetworkConfig.maxBodyBytes`.
public struct AWLDebugNetworkBody: Sendable, Hashable {
    /// The body as text, or a placeholder such as `(binary, 12 bytes)` when `isContent` is `false`.
    public let text: String
    public let contentType: String?
    /// `text` is shorter than the body.
    public let truncated: Bool
    /// Size of the whole body in bytes.
    public let originalBytes: Int
    /// `false` when `text` is a placeholder and not the body itself.
    public let isContent: Bool

    public init(text: String, contentType: String? = nil, truncated: Bool = false, originalBytes: Int, isContent: Bool = true) {
        self.text = text
        self.contentType = contentType
        self.truncated = truncated
        self.originalBytes = originalBytes
        self.isContent = isContent
    }
}

/// What `AWLDebugExtensions.exportRecording(_:)` encodes.
public struct AWLDebugRecordingExportOptions: Sendable, Hashable {
    /// Only the newest active frames of this many seconds (3 frames per second). `nil` takes all.
    public var lastSeconds: Int?
    /// Above this size the video is encoded once more at half resolution, and left out if it is still too large.
    public var maxVideoBytes: Int?
    /// A longer `timeline.md` is left out.
    public var maxTimelineBytes: Int?

    public init(lastSeconds: Int? = nil, maxVideoBytes: Int? = nil, maxTimelineBytes: Int? = nil) {
        self.lastSeconds = lastSeconds
        self.maxVideoBytes = maxVideoBytes
        self.maxTimelineBytes = maxTimelineBytes
    }
}

/// The screen recording as `recording.mp4`, `frames.jpg` and `timeline.md`.
public struct AWLDebugRecordingExport: Sendable, Hashable {
    /// H.264 MP4 at 3 frames per second, the long edge at most 1280 px.
    public let video: Data?
    /// Contact sheet: 4 columns of 270 px wide tiles, each with its time.
    public let frames: Data?
    /// Markdown table with one row per frame and per touch, keyboard or orientation event.
    public let timeline: Data?
    /// The video stayed above `maxVideoBytes` even at half resolution. All three parts are `nil` then.
    public let isVideoTooLarge: Bool

    public init(video: Data?, frames: Data?, timeline: Data?, isVideoTooLarge: Bool = false) {
        self.video = video
        self.frames = frames
        self.timeline = timeline
        self.isVideoTooLarge = isVideoTooLarge
    }
}

extension AWLDebugLogRecord {
    init(_ entry: AppLogEntry) {
        self.init(date: entry.date, level: entry.level, tag: entry.tag, message: entry.message,
                  errorDescription: entry.errorDescription)
    }
}

extension AWLDebugNetworkRecord {
    init(_ log: NetworkLog) {
        self.init(date: log.date,
                  method: log.method,
                  url: log.url,
                  statusCode: log.statusCode == 0 ? nil : log.statusCode,
                  durationMs: log.duration,
                  requestHeaders: log.requestHeaders.map { AWLDebugHeader(name: $0.name, value: $0.value) },
                  responseHeaders: log.responseHeaders.map { AWLDebugHeader(name: $0.name, value: $0.value) },
                  requestBody: log.requestBody.map(AWLDebugNetworkBody.init),
                  responseBody: log.responseBody.map(AWLDebugNetworkBody.init),
                  errorCode: log.errorCode,
                  requestBytes: log.requestBytes,
                  responseBytes: log.responseBytes)
    }
}

extension AWLDebugNetworkBody {
    init(_ body: NetworkLog.Body) {
        self.init(text: body.text, contentType: body.contentType, truncated: body.truncated,
                  originalBytes: body.originalBytes, isContent: body.isText)
    }
}
