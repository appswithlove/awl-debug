package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig

private const val REDACTED = "[REDACTED]"
private const val ESCAPED_QUOTE = "\\\""

/** `"key":` or, inside stringified JSON, `\"key\":`. Group 1 is the quote, group 2 the key. */
private val JSON_KEY_REGEX = Regex("""(\\?")([A-Za-z0-9_\-]+)\1\s*:\s*""")

private val DEFAULT_REDACTED_FIELDS: Set<String> =
    DevNetworkConfig().redactJsonFields.mapTo(mutableSetOf(), ::normalizeFieldName)

/**
 * Replaces the values of sensitive JSON fields in a log message with `"[REDACTED]"`, using the
 * same default field list as the network module. Works on JSON embedded in free text, on
 * stringified JSON (`\"password\":\"…\"`) and on truncated JSON, where an unterminated value is
 * redacted to the end of the message. Keys match ignoring case, `_` and `-`.
 */
internal fun String.redactJsonFields(fieldNames: Set<String> = DEFAULT_REDACTED_FIELDS): String {
    val result = StringBuilder()
    var copiedUntil = 0
    var searchFrom = 0
    while (true) {
        val match = JSON_KEY_REGEX.find(this, searchFrom) ?: break
        val valueStart = match.range.last + 1
        if (normalizeFieldName(match.groupValues[2]) !in fieldNames || valueStart >= length) {
            searchFrom = match.range.first + 1
            continue
        }
        val quote = match.groupValues[1]
        val valueEnd = valueEnd(valueStart, quote)
        result.append(this, copiedUntil, valueStart).append(quote).append(REDACTED).append(quote)
        copiedUntil = valueEnd
        searchFrom = valueEnd
    }
    return if (copiedUntil == 0) this else result.append(this, copiedUntil, length).toString()
}

/** Exclusive end index of the JSON value starting at [start]. */
private fun String.valueEnd(start: Int, quote: String): Int = when {
    startsWith(quote, start) -> stringEnd(start + quote.length, quote)
    this[start] == '{' || this[start] == '[' -> containerEnd(start)
    else -> indexOfAny(charArrayOf(',', '}', ']', '\n', '\r', ' ', '\t'), start).let { if (it == -1) length else it }
}

private fun String.stringEnd(contentStart: Int, quote: String): Int {
    var i = contentStart
    while (i < length) {
        when {
            quote == ESCAPED_QUOTE && startsWith("\\\\", i) -> i += 2
            startsWith(quote, i) -> return i + quote.length
            quote == "\"" && this[i] == '\\' -> i += 2
            else -> i++
        }
    }
    return length
}

private fun String.containerEnd(start: Int): Int {
    var depth = 0
    var inString = false
    var i = start
    while (i < length) {
        val c = this[i]
        when {
            inString && c == '\\' -> i++
            c == '"' -> inString = !inString
            inString -> Unit
            c == '{' || c == '[' -> depth++
            c == '}' || c == ']' -> if (--depth == 0) return i + 1
        }
        i++
    }
    return length
}

private fun normalizeFieldName(name: String): String = name.lowercase().replace("_", "").replace("-", "")
