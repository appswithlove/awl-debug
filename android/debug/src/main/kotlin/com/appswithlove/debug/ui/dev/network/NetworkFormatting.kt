package com.appswithlove.debug.ui.dev.network

import com.appswithlove.debug.api.DevConfig
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val prettyJson = Json { prettyPrint = true }

internal fun isoTimestamp(millis: Long): String =
    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).format(Date(millis))

internal fun exportTimestamp(millis: Long): String =
    SimpleDateFormat("yyyy-MM-dd_HH.mm.ss", Locale.US).format(Date(millis))

internal val NetworkEntry.statusText: String
    get() = if (isFailed) "Failed" else status.toString()

/** cURL command for the request, with redacted values kept as `[REDACTED]`. */
internal fun NetworkEntry.toCurl(): String {
    val body = requestBody
    val headers = buildList {
        val hasContentType = requestHeaders.any { it.first.equals("Content-Type", ignoreCase = true) }
        if (!hasContentType && body?.contentType != null) add("Content-Type" to body.contentType)
        addAll(requestHeaders)
    }
    val includeBody = body != null && body.isContent && !body.truncated
    val parts = buildList {
        add(if (method == "GET" && body == null) "curl ${shellQuote(url)}" else "curl -X $method ${shellQuote(url)}")
        headers.forEach { (name, value) -> add("-H ${shellQuote("$name: $value")}") }
        if (includeBody) add("--data-raw ${shellQuote(body!!.text)}")
    }
    val command = parts.joinToString(" \\\n  ")
    if (body == null || includeBody) return command
    val reason = if (body.isContent) "truncated after ${body.text.toByteArray().size} bytes" else body.text
    return "$command\n# body not included: $reason"
}

private fun shellQuote(value: String): String = "'" + value.replace("'", "'\\''") + "'"

/** Body text for display: indented JSON unless [raw] is set or the body is not complete JSON. */
internal fun CapturedBody.displayText(raw: Boolean): String {
    if (raw || !isContent || truncated || contentType?.contains("json") != true) return text
    return try {
        prettyJson.encodeToString(prettyJson.parseToJsonElement(text))
    } catch (_: SerializationException) {
        text
    } catch (_: IllegalArgumentException) {
        text
    }
}

/** One request as text, used for "Share" and the export file. */
internal fun NetworkEntry.toShareText(): String = buildString {
    append(isoTimestamp(startedAtMillis)).append(' ').append(method).append(' ').append(statusText)
        .append(' ').append(durationMs).append("ms ").append(url).append('\n')
    error?.let { append(INDENT).append("Error: ").append(it).append('\n') }
    appendSection("Request headers", requestHeaders.map { "${it.first}: ${it.second}" })
    appendSection("Request body", requestBody.bodyLines())
    appendSection("Response headers", responseHeaders.map { "${it.first}: ${it.second}" })
    appendSection("Response body", responseBody.bodyLines())
}

private fun CapturedBody?.bodyLines(): List<String> {
    if (this == null) return listOf("(no body)")
    val lines = text.lines()
    return if (truncated) lines + "(truncated, ${originalBytes ?: "?"} bytes total)" else lines
}

private fun StringBuilder.appendSection(title: String, lines: List<String>) {
    if (lines.isEmpty()) return
    append(INDENT).append(title).append(":\n")
    lines.forEach { append(INDENT).append(INDENT).append(it).append('\n') }
}

/** Export file content: app info, active filters, then one block per request. */
internal fun networkExportText(
    entries: List<NetworkEntry>,
    filter: NetworkFilter,
    devConfig: DevConfig?,
    exportedAtMillis: Long,
): String = buildString {
    append("AWL Debug network log\n")
    devConfig?.let {
        append("App: ${it.versionName} (${it.versionCode}), ${it.flavor}, ${it.buildType}\n")
        it.customParams.forEach { (key, value) -> append("$key: $value\n") }
    }
    append("Exported: ").append(isoTimestamp(exportedAtMillis)).append('\n')
    val filters = filter.describe()
    append("Filters: ").append(if (filters.isEmpty()) "none" else filters.joinToString("; ")).append('\n')
    append("Requests: ").append(entries.size).append("\n\n")
    entries.forEach { append(it.toShareText()).append('\n') }
}

private const val INDENT = "    "
