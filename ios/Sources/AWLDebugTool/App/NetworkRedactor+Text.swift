import Foundation

extension NetworkRedactor {

    // Possessive quantifiers (`*+`) keep the patterns linear: a long token such as Base64 must not backtrack.
    /// `<name attr="…">value</name>`, also with a namespace prefix. Group 1 is the name, group 2 the value.
    private static let xmlElementPattern = try! NSRegularExpression(pattern: #"<([A-Za-z_][\w.\-]*+(?::[A-Za-z_][\w.\-]*+)?)(?:\s[^<>]*+)?>([^<]*+)</\1\s*+>"#)
    /// `name="value"` or `name='value'`, as in XML attributes. Group 1 is the name, group 2 or 3 the value.
    private static let quotedAssignmentPattern = try! NSRegularExpression(pattern: #"(?<![\w.\-:])([A-Za-z_][\w.\-]*+(?::[A-Za-z_][\w.\-]*+)?)\s*+=\s*+(?:"([^"\n]*+)"|'([^'\n]*+)')"#)
    /// The whole text is `name=value&…` without whitespace.
    private static let formPattern = try! NSRegularExpression(pattern: #"^[^\s=&]++=[^\s&]*+(?:&[^\s=&]++=[^\s&]*+)*+$"#)

    /// Redacts a text body whose content type is neither JSON nor form: JSON fields anywhere in it, XML elements and
    /// attributes named like `redactJsonFields`, a body that is form data, and `Bearer` / `Basic` credentials.
    func redact(text: String, count: inout Int) -> String {
        var result = text
        let wholeRange = NSRange(location: 0, length: (text as NSString).length)
        if Self.formPattern.firstMatch(in: text, range: wholeRange) != nil {
            result = redact(pairs: result, names: fieldNames, normalize: Self.normalizedFieldName, count: &count)
        }
        result = result.redactingJsonFields(fieldNames) { count += 1 }
        result = replace(Self.xmlElementPattern, nameGroup: 1, valueGroups: [2], in: result, count: &count)
        result = replace(Self.quotedAssignmentPattern, nameGroup: 1, valueGroups: [2, 3], in: result, count: &count)
        return result.redactingCredentials(count: &count)
    }

    /// Replaces the value of each match whose name group, without a namespace prefix, is a redacted field.
    /// - Parameter valueGroups: Alternative groups for the value; the one that took part in the match is replaced.
    private func replace(_ pattern: NSRegularExpression, nameGroup: Int, valueGroups: [Int], in text: String, count: inout Int) -> String {
        let nsText = NSMutableString(string: text)
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            let name = nsText.substring(with: match.range(at: nameGroup)).components(separatedBy: ":").last ?? ""
            let valueRange = valueGroups.map { match.range(at: $0) }.first { $0.location != NSNotFound } ?? NSRange(location: NSNotFound, length: 0)
            guard fieldNames.contains(Self.normalizedFieldName(name)), valueRange.location != NSNotFound,
                  nsText.substring(with: valueRange) != Self.placeholder else {
                continue
            }
            nsText.replaceCharacters(in: valueRange, with: Self.placeholder)
            count += 1
        }
        return nsText as String
    }
}

extension String {
    /// `redactingCredentials()`, counting the replaced credentials.
    func redactingCredentials(count: inout Int) -> String {
        let redacted = redactingCredentials()
        guard redacted != self else { return self }
        let marker = " \(NetworkRedactor.placeholder)"
        count += max(redacted.components(separatedBy: marker).count - components(separatedBy: marker).count, 0)
        return redacted
    }
}
