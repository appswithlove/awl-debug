import Foundation

/// Redacts secrets and caps bodies before a request is stored. Unredacted values never leave the running request.
struct NetworkRedactor {
    static let placeholder = "[REDACTED]"
    static let alwaysRedactedHeaders: Set<String> = ["authorization", "proxy-authorization", "cookie", "set-cookie"]
    static let maxRedactableBytes = 1024 * 1024
    static let streamContentTypes: Set<String> = ["text/event-stream", "application/x-ndjson"]

    let config: AWLDebugConfig.NetworkConfig
    private let headerNames: Set<String>
    private let fieldNames: Set<String>
    private let queryNames: Set<String>
    private let streamMediaTypes: Set<String>

    init(config: AWLDebugConfig.NetworkConfig) {
        self.config = config
        headerNames = Self.alwaysRedactedHeaders.union(config.redactHeaders.map { $0.lowercased() })
        fieldNames = Set(config.redactJsonFields.map(Self.normalizedFieldName))
        queryNames = Set(config.redactQueryParams.map(Self.normalizedFieldName))
        streamMediaTypes = Self.streamContentTypes.union(config.streamContentTypes.map { Self.mediaType(of: $0) })
    }

    // MARK: - Headers and URL

    func redact(headers: [NetworkLog.Header], count: inout Int) -> [NetworkLog.Header] {
        headers.map { header in
            guard headerNames.contains(header.name.lowercased()) else { return header }
            count += 1
            return NetworkLog.Header(name: header.name, value: Self.placeholder)
        }
    }

    func redact(url: String, count: inout Int) -> String {
        guard let components = URLComponents(string: url) else { return url }
        var replacements: [(Range<String.Index>, String)] = []

        if let userInfoStart = (components.rangeOfUser ?? components.rangeOfPassword)?.lowerBound,
           let userInfoEnd = (components.rangeOfPassword ?? components.rangeOfUser)?.upperBound {
            replacements.append((userInfoStart..<userInfoEnd, Self.placeholder))
            count += 1
        }
        if let queryRange = components.rangeOfQuery {
            let query = redact(pairs: String(url[queryRange]), names: queryNames, normalize: Self.normalizedFieldName, count: &count)
            replacements.append((queryRange, query))
        }

        var result = ""
        var index = url.startIndex
        for (range, replacement) in replacements {
            result += url[index..<range.lowerBound] + replacement
            index = range.upperBound
        }
        return result + url[index...]
    }

    // MARK: - Bodies

    /// - Parameters:
    ///   - data: The captured bytes, possibly fewer than `totalBytes` when capture stopped at a limit.
    ///   - totalBytes: The full body size.
    func redact(body data: Data, totalBytes: Int, contentType: String?, count: inout Int) -> NetworkLog.Body? {
        guard totalBytes > 0 else { return nil }
        let mediaType = Self.mediaType(of: contentType)

        if mediaType.hasPrefix("multipart/"), let boundary = Self.parameter("boundary", of: contentType), data.count == totalBytes {
            return cap(redact(multipart: data, boundary: boundary, count: &count), contentType: contentType, totalBytes: totalBytes, isComplete: true)
        }
        guard Self.isText(mediaType) else {
            return Self.placeholderBody("(binary, \(totalBytes) bytes)", contentType: contentType, totalBytes: totalBytes)
        }

        let isJSON = Self.isJSON(mediaType)
        let isForm = mediaType == "application/x-www-form-urlencoded"
        guard isJSON || isForm else {
            return cap(String(decoding: data, as: UTF8.self), contentType: contentType, totalBytes: totalBytes, isComplete: data.count == totalBytes)
        }
        guard totalBytes <= Self.maxRedactableBytes, data.count == totalBytes else {
            return Self.placeholderBody("(\(totalBytes) bytes, too large to redact)", contentType: contentType, totalBytes: totalBytes)
        }

        if isForm {
            let text = redact(pairs: String(decoding: data, as: UTF8.self), names: fieldNames, normalize: Self.normalizedFieldName, count: &count)
            return cap(text, contentType: contentType, totalBytes: totalBytes, isComplete: true)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let redacted = try? JSONSerialization.data(withJSONObject: redact(json: json, count: &count),
                                                         options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]) else {
            return Self.placeholderBody("(unparsable JSON, not shown)", contentType: contentType, totalBytes: totalBytes)
        }
        return cap(String(decoding: redacted, as: UTF8.self), contentType: contentType, totalBytes: totalBytes, isComplete: true)
    }

    private func redact(json: Any, count: inout Int) -> Any {
        if let object = json as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, value) in object {
                if fieldNames.contains(Self.normalizedFieldName(key)) {
                    result[key] = Self.placeholder
                    count += 1
                } else {
                    result[key] = redact(json: value, count: &count)
                }
            }
            return result
        }
        if let array = json as? [Any] {
            return array.map { redact(json: $0, count: &count) }
        }
        return json
    }

    /// Redacts `name=value` pairs of a query string or form body, keeping everything else byte for byte.
    private func redact(pairs: String, names: Set<String>, normalize: (String) -> String, count: inout Int) -> String {
        pairs.split(separator: "&", omittingEmptySubsequences: false).map { pair -> String in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawName = String(parts[0])
            let name = rawName.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? rawName
            guard parts.count == 2, names.contains(normalize(name)) else { return String(pair) }
            count += 1
            return "\(rawName)=\(Self.placeholder)"
        }
        .joined(separator: "&")
    }

    private func redact(multipart data: Data, boundary: String, count: inout Int) -> String {
        let delimiter = Data("--\(boundary)".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        var parts: [String] = []
        var searchStart = data.startIndex

        while let delimiterRange = data.range(of: delimiter, in: searchStart..<data.endIndex) {
            defer { searchStart = delimiterRange.upperBound }
            guard let nextDelimiter = data.range(of: delimiter, in: delimiterRange.upperBound..<data.endIndex),
                  let separator = data.range(of: headerSeparator, in: delimiterRange.upperBound..<nextDelimiter.lowerBound) else {
                continue
            }
            let headers = String(decoding: data[delimiterRange.upperBound..<separator.lowerBound], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var body = data[separator.upperBound..<nextDelimiter.lowerBound]
            if body.suffix(2) == Data("\r\n".utf8) {
                body = body.dropLast(2)
            }

            let disposition = headers.components(separatedBy: "\r\n").first { $0.lowercased().hasPrefix("content-disposition:") }
            let partType = headers.components(separatedBy: "\r\n")
                .first { $0.lowercased().hasPrefix("content-type:") }
                .map { String($0.dropFirst("content-type:".count)).trimmingCharacters(in: .whitespaces) }
            let content: String
            if let filename = Self.parameter("filename", of: disposition) {
                content = "(file \(filename), \(body.count) bytes)"
            } else if let name = Self.parameter("name", of: disposition), fieldNames.contains(Self.normalizedFieldName(name)) {
                content = Self.placeholder
                count += 1
            } else if let partBody = redact(body: Data(body), totalBytes: body.count, contentType: partType ?? "text/plain", count: &count) {
                content = partBody.text
            } else {
                content = ""
            }
            parts.append("--\(boundary)\r\n\(headers)\r\n\r\n\(content)")
        }
        return parts.joined(separator: "\r\n") + "\r\n--\(boundary)--"
    }

    private func cap(_ text: String, contentType: String?, totalBytes: Int, isComplete: Bool) -> NetworkLog.Body {
        guard text.utf8.count > config.maxBodyBytes || !isComplete else {
            return NetworkLog.Body(text: text, contentType: contentType, originalBytes: totalBytes)
        }
        var length = min(config.maxBodyBytes, text.utf8.count)
        var prefix = String(text.utf8.prefix(length))
        // Step back so a multi-byte character is not cut in half.
        while prefix == nil, length > 0 {
            length -= 1
            prefix = String(text.utf8.prefix(length))
        }
        return NetworkLog.Body(text: prefix ?? "", contentType: contentType, originalBytes: totalBytes, truncated: true)
    }

    static func placeholderBody(_ text: String, contentType: String?, totalBytes: Int) -> NetworkLog.Body {
        NetworkLog.Body(text: text, contentType: contentType, originalBytes: totalBytes, isText: false)
    }

    // MARK: - Content types

    static func mediaType(of contentType: String?) -> String {
        (contentType ?? "").split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
    }

    static func isJSON(_ mediaType: String) -> Bool {
        mediaType == "application/json" || mediaType.hasSuffix("+json")
    }

    static func isText(_ mediaType: String) -> Bool {
        mediaType.hasPrefix("text/")
            || isJSON(mediaType)
            || mediaType.hasSuffix("+xml")
            || ["application/xml", "application/x-www-form-urlencoded", "application/graphql"].contains(mediaType)
    }

    /// Stream bodies are never read: buffering them would hold back or never finish the response.
    func isStreamResponse(statusCode: Int, contentType: String?) -> Bool {
        statusCode == 101 || isStream(contentType: contentType)
    }

    func isStream(contentType: String?) -> Bool {
        streamMediaTypes.contains(Self.mediaType(of: contentType))
    }

    /// Bytes to keep of a body before redaction. Redaction needs the whole document; larger ones are reported as too large to redact.
    func captureLimit(contentType: String?) -> Int {
        let mediaType = Self.mediaType(of: contentType)
        guard Self.isJSON(mediaType) || mediaType == "application/x-www-form-urlencoded" || mediaType.hasPrefix("multipart/") else {
            return config.maxBodyBytes
        }
        return max(config.maxBodyBytes, Self.maxRedactableBytes)
    }

    private static func parameter(_ name: String, of headerValue: String?) -> String? {
        guard let headerValue = headerValue else { return nil }
        for component in headerValue.split(separator: ";").dropFirst() {
            let pair = component.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased() == name else { continue }
            return pair[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }

    static func normalizedFieldName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
    }
}
