//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import Foundation

/// A `multipart/form-data` body.
struct MultipartFormData {
    let boundary: String
    private var body = Data()

    init(boundary: String = "AWLFeedback-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(name: String, value: String) {
        appendBoundary()
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        appendBoundary()
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    func finalized() -> Data {
        var result = body
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }

    private mutating func appendBoundary() {
        append("--\(boundary)\r\n")
    }

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }
}
