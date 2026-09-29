//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// Builds and posts reports to the feedback service.
struct FeedbackClient {
    let endpoint: URL
    let appKey: String

    /// `idempotencyKey` identifies the report on the service, so every attempt of one report must use the same key.
    func makeRequest(
        text: String,
        metadata: FeedbackMetadata,
        screenshotJPEG: Data,
        logs: Data? = nil,
        recording: RecordingAttachment? = nil,
        idempotencyKey: UUID
    ) throws -> URLRequest {
        var form = MultipartFormData()
        form.addField(name: "text", value: text)
        try form.addField(name: "metadata", value: metadata.jsonString())
        form.addFile(name: "screenshot", filename: "screenshot.jpg", mimeType: "image/jpeg", data: screenshotJPEG)
        if let logs {
            form.addFile(name: "logs", filename: "logs.txt", mimeType: "text/plain; charset=utf-8", data: logs)
        }
        if let video = recording?.video {
            form.addFile(name: "video", filename: "recording.mp4", mimeType: "video/mp4", data: video)
            if let frames = recording?.frames {
                form.addFile(name: "frames", filename: "frames.jpg", mimeType: "image/jpeg", data: frames)
            }
            if let timeline = recording?.timeline {
                form.addFile(name: "timeline", filename: "timeline.md", mimeType: "text/markdown; charset=utf-8", data: timeline)
            }
        }

        var request = URLRequest(url: endpoint.appending(path: "v1/feedback"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(idempotencyKey.uuidString.lowercased(), forHTTPHeaderField: FeedbackClient.idempotencyHeader)
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.finalized()
        return request
    }

    static let idempotencyHeader = "Idempotency-Key"
    /// The service reads at most 32 MiB per report.
    static let maxBodyBytes = 32 * 1024 * 1024

    /// Sends one attempt of a report built by `makeRequest`.
    static func send(_ request: URLRequest, session: URLSession) async throws(FeedbackFailure) {
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw FeedbackFailure(error: FeedbackError(urlError: error))
        } catch {
            throw FeedbackFailure(error: .network)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FeedbackFailure(error: .network)
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
            throw FeedbackFailure(
                error: FeedbackError(statusCode: http.statusCode, retryAfter: retryAfter),
                retryAfterSeconds: FeedbackError.seconds(retryAfter: retryAfter)
            )
        }
    }
}

/// A failed attempt, with the service's `Retry-After` if it sent one.
struct FeedbackFailure: Error, Equatable {
    let error: FeedbackError
    var retryAfterSeconds: Int?
}
