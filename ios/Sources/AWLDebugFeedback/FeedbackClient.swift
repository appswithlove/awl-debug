//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// Posts a report to the feedback service.
struct FeedbackClient {
    let endpoint: URL
    let appKey: String
    var session: URLSession = .shared

    func makeRequest(text: String, metadata: FeedbackMetadata, screenshotJPEG: Data) throws -> URLRequest {
        var form = MultipartFormData()
        form.addField(name: "text", value: text)
        try form.addField(name: "metadata", value: metadata.jsonString())
        form.addFile(name: "screenshot", filename: "screenshot.jpg", mimeType: "image/jpeg", data: screenshotJPEG)

        var request = URLRequest(url: endpoint.appending(path: "v1/feedback"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.finalized()
        return request
    }

    /// Returns the id of the created task.
    func send(text: String, metadata: FeedbackMetadata, screenshotJPEG: Data) async throws(FeedbackError) -> String? {
        let request: URLRequest
        do {
            request = try makeRequest(text: text, metadata: metadata, screenshotJPEG: screenshotJPEG)
        } catch {
            throw .encodingFailed
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw FeedbackError(urlError: error)
        } catch {
            throw .network
        }

        guard let http = response as? HTTPURLResponse else {
            throw .network
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FeedbackError(statusCode: http.statusCode, retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
        }
        return (try? JSONDecoder().decode(CreatedResponse.self, from: data))?.taskId
    }

    private struct CreatedResponse: Decodable {
        let taskId: String
    }
}
