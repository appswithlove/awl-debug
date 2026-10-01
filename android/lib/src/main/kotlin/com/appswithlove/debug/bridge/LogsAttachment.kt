package com.appswithlove.debug.bridge

import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.DevBridge
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.LogCollector
import com.appswithlove.debug.ui.dev.log.LogEntry
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.networkErrorCode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal const val ATTACHMENT_MAX_LOGS = 500
internal const val ATTACHMENT_MAX_REQUESTS = 50
private const val INDENT = "    "

/** Lets the feedback artifact attach logs and requests as the body of `logs.txt`. */
@OptIn(AwlDebugInternalApi::class)
internal object LogsAttachment {
    fun register() {
        DevBridge.feedbackAttachments = { withContext(Dispatchers.Default) { current().toByteArray(Charsets.UTF_8) } }
    }

    private fun current(): String {
        val history = LogCollector.logHistory
        return logsAttachmentBody(
            logs = history.filteredSnapshot().takeLast(ATTACHMENT_MAX_LOGS),
            filters = describeFilters(history.selectedSeverityTags.value, history.query.value),
            requests = NetworkCollector.store.entries.value.takeLast(ATTACHMENT_MAX_REQUESTS),
            maxBytes = DevBridge.LOGS_ATTACHMENT_BODY_MAX_BYTES,
            timeZone = TimeZone.getDefault(),
        )
    }
}

/** `filters:` value, e.g. `severity=ERROR,WARN search="checkout"`, or `none`. */
internal fun describeFilters(severities: List<DevLogSeverity>, query: String): String {
    val parts = buildList {
        if (severities.isNotEmpty()) add("severity=" + severities.sortedDescending().joinToString(","))
        if (query.isNotEmpty()) add("search=\"" + query.replace("\"", "\\\"") + "\"")
    }
    return parts.ifEmpty { listOf("none") }.joinToString(" ")
}

/**
 * Everything of `logs.txt` from the `filters:` line on. [logs] and [requests] are already redacted, oldest first.
 * When the text would exceed [maxBytes], the oldest logs are left out first, then the oldest requests.
 */
internal fun logsAttachmentBody(
    logs: List<LogEntry>,
    filters: String,
    requests: List<NetworkEntry>,
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

private fun LogEntry.attachmentText(formatter: SimpleDateFormat): String = buildString {
    val lines = message.clean().lines()
    append(formatter.format(Date(timestamp))).append(" | ").append(severity?.name ?: "-")
        .append(" | ").append(tag?.clean()?.ifBlank { null } ?: "-").append(" | ").append(lines.first()).append('\n')
    lines.drop(1).forEach { append(INDENT).append(it).append('\n') }
    throwable?.let { error ->
        error.stackTraceToString().clean().trimEnd().lines().forEach { line ->
            append(INDENT).append(line.replace("\t", INDENT)).append('\n')
        }
    }
}

private fun NetworkEntry.attachmentText(formatter: SimpleDateFormat): String = buildString {
    append(formatter.format(Date(startedAtMillis))).append(' ').append(method).append(' ')
        .append(if (isFailed) "-" else status.toString()).append(' ').append(durationMs).append("ms ").append(url.clean())
        .append('\n')
    requestHeaders.forEach { (name, value) -> append(INDENT).append("> ").append(name.lowercase()).append(": ").append(value.clean()).append('\n') }
    responseHeaders.forEach { (name, value) -> append(INDENT).append("< ").append(name.lowercase()).append(": ").append(value.clean()).append('\n') }
    if (isFailed) append(INDENT).append("! ").append(errorCode ?: networkErrorCode(error)).append('\n')
}

/** One line ending, no NUL bytes: the service rejects `logs.txt` with NUL bytes. */
private fun String.clean(): String = replace("\r\n", "\n").replace('\r', '\n').replace('\u0000', '�')

private fun String.utf8Size(): Int = toByteArray(Charsets.UTF_8).size
