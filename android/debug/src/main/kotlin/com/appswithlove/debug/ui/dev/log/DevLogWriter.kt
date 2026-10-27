package com.appswithlove.debug.ui.dev.log

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.update
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicLong
import kotlin.collections.minus
import kotlin.collections.plus

@Suppress("Unused")
internal class DevLogWriter(private val logHistory: LogHistory) : DevLogCollector {
    override fun setTrackLogs(track: Boolean) {
        logHistory.setTrackLogs(track)
    }

    override fun log(log: Log) {
        logHistory.push(
            LogEntry(
                severity = log.severity,
                message = log.message.redactCredentials().redactJsonFields(),
                tag = log.tag,
                stackTrace = log.throwable?.stackTraceToString()?.redactCredentials()?.redactJsonFields(),
            ),
        )
    }

    override fun setMaxSize(size: Int) {
        logHistory.setMaxSize(size)
    }
}

class LogHistory {
    private val _trackLogs = MutableStateFlow(true)
    internal val trackLogs = _trackLogs.asStateFlow()

    private val _maxSize = MutableStateFlow(750)
    internal val maxSize = _maxSize.asStateFlow()

    private val _logEntries = MutableStateFlow<List<LogEntry>>(emptyList())
    internal val logEntries = _logEntries.asStateFlow()

    private val _query = MutableStateFlow("")
    internal val query = _query.asStateFlow()

    private val _selectedSeverityTags = MutableStateFlow<List<DevLogSeverity>>(emptyList())
    internal val selectedSeverityTags = _selectedSeverityTags.asStateFlow()

    /** Entries matching the search and the selected severities; the same filter applies to the export. */
    internal val filteredLogEntries = combine(
        _maxSize,
        _logEntries,
        _query,
        _selectedSeverityTags,
    ) { maxSize, logs, query, severities ->
        logs.filter { it.matches(query, severities) }.take(maxSize)
    }

    /** Current entries after search and severity filter, for the export. */
    internal fun filteredSnapshot(): List<LogEntry> =
        _logEntries.value.filter { it.matches(_query.value, _selectedSeverityTags.value) }

    private fun LogEntry.matches(query: String, severities: List<DevLogSeverity>): Boolean =
        (severities.isEmpty() || severity in severities) &&
            (message.contains(query, true) || tag?.contains(query, true) == true)

    internal fun push(entry: LogEntry) {
        if (_trackLogs.value) {
            _logEntries.update { (it + entry).takeLast(_maxSize.value) }
        }
    }

    internal fun search(query: String) {
        _query.value = query
    }

    internal fun filterBySeverity(severity: DevLogSeverity) {
        if (severity in _selectedSeverityTags.value) {
            _selectedSeverityTags.value -= severity
        } else {
            _selectedSeverityTags.value += severity
        }
    }

    internal fun clear() {
        _logEntries.value = emptyList()
    }

    internal fun setMaxSize(size: Int) {
        _maxSize.value = size
    }

    internal fun setTrackLogs(track: Boolean) {
        _trackLogs.value = track
    }

    internal companion object {
        val Preview = LogHistory()
        val PreviewEmpty = LogHistory()

        val PreviewTrackLogsDisabled = LogHistory()

        init {
            Preview.push(
                entry = LogEntry(
                    severity = DevLogSeverity.ERROR,
                    message = "--> POST https://someendpoint.com/api/v1/action\n" +
                            "Headers: \n" +
                            "\n" +
                            "Body: {\"username\":\"mruser\",\"locale\":\"en\"}\n" +
                            "--> END POST\n"
                )
            )
            Preview.push(
                entry = LogEntry(
                    severity = DevLogSeverity.WARN,
                    message = "--> POST https://someendpoint.com/api/v1/action\n" +
                            "Headers: \n" +
                            "\n" +
                            "Body: {\"username\":\"mruser\",\"locale\":\"en\"}\n" +
                            "--> END POST\n"
                )
            )
            Preview.push(
                entry = LogEntry(
                    severity = DevLogSeverity.DEBUG,
                    message = "--> POST https://someendpoint.com/api/v1/action\n" +
                            "Headers: \n" +
                            "\n" +
                            "Body: {\"username\":\"mruser\",\"locale\":\"en\"}\n" +
                            "--> END POST\n"
                )
            )
            Preview.push(
                entry = LogEntry(
                    severity = DevLogSeverity.INFO,
                    message = "<-- 200  https://someendpoint.com/api/v1/action (680ms)\n" +
                            "Headers: \n" +
                            "date: Thu, 06 Nov 2025 10:52:36 GMT\n" +
                            "content-type: application/json\n" +
                            "\n" +
                            "Body: {\"username\":\"mruser\",\"locale\":\"en\"}\n" +
                            "<-- END HTTP\n"
                )
            )
            PreviewTrackLogsDisabled.setTrackLogs(false)
        }
    }
}

private val nextLogEntryId = AtomicLong()

internal data class LogEntry(
    val severity: DevLogSeverity?,
    val message: String,
    val timestamp: Long = System.currentTimeMillis(),
    val tag: String? = null,
    /** Redacted stack trace of the logged throwable. */
    val stackTrace: String? = null,
    val id: Long = nextLogEntryId.getAndIncrement(),
) {
    private val tagPrefix: String = tag?.let { "$it | " }.orEmpty()

    /** Message followed by the stack trace, as shown in the Logs module and the export. */
    val fullMessage: String = stackTrace?.let { "$message\n$it" } ?: message

    val formattedTime: String = SimpleDateFormat(
        "dd.MM.yyyy HH:mm:ss",
        Locale.getDefault()
    ).format(Date(timestamp))

    fun toExportString(): String {
        return "$formattedTime | $severity | $tagPrefix$fullMessage"
    }

    override fun toString(): String {
        return "$formattedTime | $tagPrefix$fullMessage"
    }
}
