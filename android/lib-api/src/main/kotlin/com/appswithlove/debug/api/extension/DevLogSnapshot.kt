package com.appswithlove.debug.api.extension

/**
 * Log entries as the Logs module shows them, with its filter.
 *
 * @param records The newest entries that match [severityFilter] and [searchQuery], oldest first, already redacted.
 * @param severityFilter Severities selected in the Logs module, most severe first; empty when all are shown.
 * @param searchQuery Search text of the Logs module; empty without a search.
 */
class DevLogSnapshot(
    val records: List<DevLogRecord>,
    val severityFilter: List<String>,
    val searchQuery: String,
)

/**
 * One log entry.
 *
 * @param timestampMillis When it was logged, in milliseconds since the epoch.
 * @param severity `DEBUG`, `INFO`, `WARN` or `ERROR`; `null` when unknown.
 * @param tag Log tag; `null` without one.
 * @param message Message, may span several lines.
 * @param throwable Stack trace of the logged exception; `null` without one.
 */
class DevLogRecord(
    val timestampMillis: Long,
    val severity: String?,
    val tag: String?,
    val message: String,
    val throwable: String?,
)
