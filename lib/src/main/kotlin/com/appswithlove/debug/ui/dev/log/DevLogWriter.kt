package com.appswithlove.debug.ui.dev.log

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.collections.minus
import kotlin.collections.plus

@Suppress("Unused")
class DevLogWriter(private val logHistory: LogHistory) : DevLogCollector {
    override fun setTrackLogs(track: Boolean) {
        logHistory.setTrackLogs(track)
    }

    override fun log(log: Log) {
        logHistory.push(LogEntry(log.severity, log.message))
    }

    override fun setMaxSize(size: Int) {
        logHistory.setMaxSize(size)
    }
}

class LogHistory {
    private val _trackLogs = MutableStateFlow(true)
    val trackLogs = _trackLogs.asStateFlow()

    private val _maxSize = MutableStateFlow(750)
    val maxSize = _maxSize.asStateFlow()

    private val _logEntries = MutableStateFlow<List<LogEntry>>(emptyList())
    val logEntries = _logEntries.asStateFlow()

    private val _query = MutableStateFlow("")
    val query = _query.asStateFlow()

    private val _selectedSeverityTags = MutableStateFlow<List<DevLogSeverity>>(emptyList())
    val selectedSeverityTags = _selectedSeverityTags.asStateFlow()

    val filteredLogEntries = combine(
        _maxSize,
        _logEntries,
        _query
    ) { maxSize, logs, query ->
        logs.filter {
            it.message.contains(query, true)
        }.take(maxSize)
    }

    fun push(entry: LogEntry) {
        if (_trackLogs.value) {
            val updatedLogs = (_logEntries.value + entry).let {
                if (it.size > _maxSize.value) it.takeLast(_maxSize.value) else it
            }
            _logEntries.value = updatedLogs
        }
    }

    fun search(query: String) {
        _query.value = query
    }

    fun filterBySeverity(severity: DevLogSeverity) {
        if (severity in _selectedSeverityTags.value) {
            _selectedSeverityTags.value -= severity
        } else {
            _selectedSeverityTags.value += severity
        }
    }

    fun clear() {
        _logEntries.value = emptyList()
    }

    fun setMaxSize(size: Int) {
        _maxSize.value = size
    }

    fun setTrackLogs(track: Boolean) {
        _trackLogs.value = track
    }

    companion object {
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

data class LogEntry(
    val severity: DevLogSeverity?,
    val message: String,
    val timestamp: Long = System.currentTimeMillis(),
) {
    val formattedTime: String = SimpleDateFormat(
        "dd.MM.yyyy HH:mm:ss",
        Locale.getDefault()
    ).format(Date(timestamp))

    fun toExportString(): String {
        return "$formattedTime | $severity | $message"
    }

    override fun toString(): String {
        return "$formattedTime | $message"
    }
}
