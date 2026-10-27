package com.appswithlove.debug.extension

import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevExtensionProvider
import com.appswithlove.debug.api.extension.DevLogRecord
import com.appswithlove.debug.api.extension.DevLogSnapshot
import com.appswithlove.debug.api.extension.DevNetworkBody
import com.appswithlove.debug.api.extension.DevNetworkRecord
import com.appswithlove.debug.api.extension.DevRecordingExport
import com.appswithlove.debug.api.extension.DevRecordingExportOptions
import com.appswithlove.debug.ui.dev.log.LogCollector
import com.appswithlove.debug.ui.dev.log.LogEntry
import com.appswithlove.debug.ui.dev.network.CapturedBody
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.recording.ScreenRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Serves [AwlDebugExtensions] from the panel's logs, requests and screen recording. */
@OptIn(AwlDebugInternalApi::class)
internal object DebugExtensionProvider : DevExtensionProvider {
    fun install() {
        AwlDebugExtensions.installProvider(this)
    }

    override suspend fun logSnapshot(maxEntries: Int): DevLogSnapshot = withContext(Dispatchers.Default) {
        val history = LogCollector.logHistory
        DevLogSnapshot(
            records = history.filteredSnapshot().takeLast(maxEntries).map { it.toRecord() },
            severityFilter = history.selectedSeverityTags.value.sortedDescending().map { it.name },
            searchQuery = history.query.value,
        )
    }

    override fun networkSnapshot(maxEntries: Int): List<DevNetworkRecord> =
        NetworkCollector.store.entries.value.takeLast(maxEntries).map { it.toRecord() }

    override fun hasRecording(): Boolean = ScreenRecorder.hasRecording()

    override suspend fun exportRecording(options: DevRecordingExportOptions): DevRecordingExport? =
        ScreenRecorder.export(options)
}

private fun LogEntry.toRecord() = DevLogRecord(
    timestampMillis = timestamp,
    severity = severity?.name,
    tag = tag,
    message = message,
    throwable = stackTrace,
)

internal fun NetworkEntry.toRecord() = DevNetworkRecord(
    startedAtMillis = startedAtMillis,
    method = method,
    url = url,
    status = status.takeUnless { isFailed },
    durationMs = durationMs,
    requestHeaders = requestHeaders,
    responseHeaders = responseHeaders,
    requestBody = requestBody?.toRecord(),
    responseBody = responseBody?.toRecord(),
    errorCode = errorCode,
    requestBytes = requestBytes,
    responseBytes = responseBytes,
)

private fun CapturedBody.toRecord() = DevNetworkBody(
    text = text,
    contentType = contentType,
    truncated = truncated,
    originalBytes = originalBytes,
    isContent = isContent,
)
