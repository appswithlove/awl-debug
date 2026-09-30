package com.appswithlove.debug.feedback.attachments

import com.appswithlove.debug.api.extension.DevLogRecord
import com.appswithlove.debug.api.extension.DevNetworkRecord
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal const val ATTACHMENT_MAX_LOGS = 500
internal const val ATTACHMENT_MAX_REQUESTS = 50

/** Room left in the 1 MiB `logs.txt` for its header. */
internal const val LOGS_BODY_MAX_BYTES = LOGS_MAX_BYTES - 4 * 1024
private const val INDENT = "    "

/** `filters:` value, e.g. `severity=ERROR,WARN search="checkout"`, or `none`. [severities] come most severe first. */
internal fun describeFilters(severities: List<String>, query: String): String {
    val parts = buildList {
        if (severities.isNotEmpty()) add("severity=" + severities.joinToString(","))
        if (query.isNotEmpty()) add("search=\"" + query.replace("\"", "\\\"") + "\"")
    }
    return parts.ifEmpty { listOf("none") }.joinToString(" ")
}

/**
 * Everything of `logs.txt` from the `filters:` line on. [logs] and [requests] are already redacted, oldest first.
 * When the text would exceed [maxBytes], the oldest logs are left out first, then the oldest requests.
 */
internal fun logsAttachmentBody(
    logs: List<DevLogRecord>,
    filters: String,
    requests: List<DevNetworkRecord>,
    maxBytes: Int,
    timeZone: TimeZone,
): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply { this.timeZone = timeZone }
    val logBlocks = logs.map { it.attachmentText(formatter) }
    val requestBlocks = requests.map { it.attachmentText(formatter) }
    val fixed = "filters: ${filters.clean()}\n\n" + section("Logs", 0, ATTACHMENT_MAX_LOGS, 0, emptyList()) +
        "\n" + section("Network", 0, ATTACHMENT_MAX_REQUESTS, 0, emptyList())
    // Reserve room for both "omitted" lines and wider counts in the headings.
    var budget = maxBytes - fixed.utf8Size() - 2 * 64
    val keptRequests = requestBlocks.newestWithin(budget)
    budget -= keptRequests.sumOf { it.utf8Size() }
    val keptLogs = logBlocks.newestWithin(budget)
    return "filters: ${filters.clean()}\n\n" +
        section("Logs", keptLogs.size, ATTACHMENT_MAX_LOGS, logBlocks.size - keptLogs.size, keptLogs) +
        "\n" +
        section("Network", keptRequests.size, ATTACHMENT_MAX_REQUESTS, requestBlocks.size - keptRequests.size, keptRequests)
}

private fun section(title: String, shown: Int, max: Int, omitted: Int, blocks: List<String>): String = buildString {
    append("## ").append(title).append(" (").append(shown).append(" of ").append(max).append(")\n")
    if (omitted > 0) append("… ").append(omitted).append(" older entries omitted\n")
    blocks.forEach(::append)
}

/** Newest blocks that fit into [budget] bytes together, oldest first; stops at the first one that does not fit. */
private fun List<String>.newestWithin(budget: Int): List<String> {
    var left = budget
    val kept = ArrayDeque<String>()
    for (block in asReversed()) {
        val size = block.utf8Size()
        if (size > left) break
        left -= size
        kept.addFirst(block)
    }
    return kept
}

private fun DevLogRecord.attachmentText(formatter: SimpleDateFormat): String = buildString {
    val lines = message.clean().lines()
    append(formatter.format(Date(timestampMillis))).append(" | ").append(severity ?: "-")
        .append(" | ").append(tag?.clean()?.ifBlank { null } ?: "-").append(" | ").append(lines.first()).append('\n')
    lines.drop(1).forEach { append(INDENT).append(it).append('\n') }
    throwable?.let { stackTrace ->
        stackTrace.clean().trimEnd().lines().forEach { line ->
            append(INDENT).append(line.replace("\t", INDENT)).append('\n')
        }
    }
}

private fun DevNetworkRecord.attachmentText(formatter: SimpleDateFormat): String = buildString {
    append(formatter.format(Date(startedAtMillis))).append(' ').append(method).append(' ')
        .append(status?.toString() ?: "-").append(' ').append(durationMs).append("ms ").append(url.clean())
        .append('\n')
    requestHeaders.forEach { (name, value) -> append(INDENT).append("> ").append(name.lowercase()).append(": ").append(value.clean()).append('\n') }
    responseHeaders.forEach { (name, value) -> append(INDENT).append("< ").append(name.lowercase()).append(": ").append(value.clean()).append('\n') }
    if (status == null) append(INDENT).append("! ").append(errorCode ?: "connection").append('\n')
}

/** One line ending, no NUL bytes: the service rejects `logs.txt` with NUL bytes. */
private fun String.clean(): String = replace("\r\n", "\n").replace('\r', '\n').replace('\u0000', '�')

private fun String.utf8Size(): Int = toByteArray(Charsets.UTF_8).size
