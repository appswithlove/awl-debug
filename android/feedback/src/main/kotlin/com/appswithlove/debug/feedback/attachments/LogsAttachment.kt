package com.appswithlove.debug.feedback.attachments

import android.util.Log
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevLogSnapshot
import com.appswithlove.debug.api.extension.DevNetworkRecord
import com.appswithlove.debug.feedback.DeviceInfo
import com.appswithlove.debug.feedback.FeedbackConfig
import com.appswithlove.debug.feedback.FeedbackPart
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** The service accepts `logs.txt` up to 1 MiB. */
internal const val LOGS_MAX_BYTES = 1024 * 1024
private const val MAX_HEADER_VALUE_LENGTH = 200
private const val LOG_TAG = "Feedback"

internal fun logsPart(bytes: ByteArray) = FeedbackPart("logs", "logs.txt", "text/plain; charset=utf-8", bytes)

/**
 * Builds `logs.txt`: the header, then the newest logs (with the Logs module's filter) and requests of the debug panel.
 * Returns `null` without the debug panel, when it fails, or when the result would be too large.
 */
internal suspend fun captureLogsAttachment(
    config: FeedbackConfig,
    device: DeviceInfo,
    generatedAt: Date,
    timeZone: TimeZone = TimeZone.getDefault(),
    logs: suspend () -> DevLogSnapshot? = { AwlDebugExtensions.logSnapshot(ATTACHMENT_MAX_LOGS) },
    requests: () -> List<DevNetworkRecord> = { AwlDebugExtensions.networkSnapshot(ATTACHMENT_MAX_REQUESTS) },
): ByteArray? {
    val body = try {
        val snapshot = logs() ?: return null
        val recentRequests = requests()
        withContext(Dispatchers.Default) {
            logsAttachmentBody(
                logs = snapshot.records,
                filters = describeFilters(snapshot.severityFilter, snapshot.searchQuery),
                requests = recentRequests,
                maxBytes = LOGS_BODY_MAX_BYTES,
                timeZone = timeZone,
            )
        }
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.w(LOG_TAG, "Could not collect logs for the report", e)
        return null
    }
    val bytes = (logsAttachmentHeader(config, device, generatedAt, timeZone) + body).toByteArray(Charsets.UTF_8)
    return bytes.takeIf { it.size <= LOGS_MAX_BYTES }
}

internal fun logsAttachmentHeader(config: FeedbackConfig, device: DeviceInfo, generatedAt: Date, timeZone: TimeZone): String {
    val app = listOfNotNull(
        "${config.appVersion.headerValue()} (${config.buildNumber.headerValue()})",
        config.environment.headerValue(),
        config.distribution?.wireValue,
    ).joinToString(" · ")
    val deviceLine = listOf("android ${device.osVersion.headerValue()}", device.deviceModel.headerValue(), device.locale.headerValue())
        .joinToString(" · ")
    val generated = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply { this.timeZone = timeZone }.format(generatedAt)
    return "# AWL Debug logs\napp: $app\ndevice: $deviceLine\ngenerated: $generated\n"
}

/** Single line, capped like the metadata strings, so the header always fits the room [LOGS_BODY_MAX_BYTES] leaves. */
private fun String.headerValue(): String = replace(Regex("[\\r\\n\\u0000]"), " ").take(MAX_HEADER_VALUE_LENGTH)
