package com.appswithlove.debug.feedback.reporting

import com.appswithlove.debug.api.extension.DevNetworkBody
import com.appswithlove.debug.api.extension.DevNetworkRecord
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Wire format of `session-batch.v1`: limits the service enforces, applied on the device. */
internal object ReportingJson {
    const val MAX_BODY_BYTES = 64 * 1024
    private const val MAX_HEADER_VALUE = 4096
    private const val MAX_HEADERS = 100
    private const val MAX_URL = 8192
    private const val MAX_ERROR = 1000
    private const val MAX_SHORT_STRING = 200
    private const val REDACTED = "[REDACTED]"

    private val METHOD = Regex("^[A-Z]{1,16}$")
    private val URL_SCHEME = Regex("^(https?|wss?)://")
    private val HEADER_NAME = Regex("^[a-z0-9!#$%&'*+.^_`|~-]{1,128}$")

    /** The service requires these to be redacted, on top of what `DevHttpLogInterceptor` always redacts. */
    private val REDACTED_HEADERS = setOf(
        "authorization", "proxy-authorization", "cookie", "set-cookie", "x-app-key", "x-api-key",
    )

    fun timestamp(millis: Long): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        .apply { timeZone = TimeZone.getTimeZone("UTC") }
        .format(Date(millis))

    fun shortString(value: String?): String = value.orEmpty().trim().take(MAX_SHORT_STRING).ifEmpty { "unknown" }

    /** Lowercase hex SHA-256 of `appKey:appUserId`; the plain id never leaves the device. */
    fun userIdentifier(appKey: String, appUserId: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest("$appKey:$appUserId".toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    /** Returns `null` for requests the service cannot store, such as non-HTTP URLs. */
    fun networkLog(record: DevNetworkRecord, captureBodies: Boolean, maxBodyBytes: Int): JsonObject? {
        if (!METHOD.matches(record.method) || !URL_SCHEME.containsMatchIn(record.url)) return null
        val status = record.status
        return buildJsonObject {
            put("ts", timestamp(record.startedAtMillis))
            put("method", record.method)
            put("url", record.url.take(MAX_URL))
            if (status != null && status in 100..599) {
                put("status", status)
            } else {
                put("error", record.errorCode ?: "connection")
            }
            put("durationMs", record.durationMs.coerceAtLeast(0))
            record.requestBytes?.takeIf { it >= 0 }?.let { put("requestBytes", it) }
            record.responseBytes?.takeIf { it >= 0 }?.let { put("responseBytes", it) }
            headers(record.requestHeaders)?.let { put("requestHeaders", it) }
            headers(record.responseHeaders)?.let { put("responseHeaders", it) }
            if (captureBodies) {
                body(record.requestBody, maxBodyBytes)?.let { put("requestBody", it) }
                body(record.responseBody, maxBodyBytes)?.let { put("responseBody", it) }
            }
        }
    }

    fun metric(sample: ReportingMetricSample): JsonObject? {
        val json = buildJsonObject {
            put("ts", timestamp(sample.timestampMillis))
            sample.cpuPercent?.let { put("cpuPercent", roundTo1(it.coerceIn(0.0, 100.0))) }
            sample.ramBytes?.takeIf { it >= 0 }?.let { put("ramBytes", it) }
            sample.batteryPercent?.takeIf { it in 0..100 }?.let { put("batteryPercent", it) }
            sample.uiFreezeMs?.takeIf { it >= 0 }?.let { put("uiFreezeMs", it) }
        }
        return json.takeIf { it.size > 1 }
    }

    fun session(session: ReportingSession): JsonObject = buildJsonObject {
        put("id", session.id)
        session.userIdentifier?.let { put("userIdentifier", it) }
        put("startedAt", timestamp(session.startedAtMillis))
        session.endedAtMillis?.let { put("endedAt", timestamp(it)) }
        put("platform", "android")
        put("appVersion", shortString(session.appVersion))
        put("buildNumber", shortString(session.buildNumber))
        put("environment", shortString(session.environment))
        put("distribution", session.distribution)
        put("sdkVersion", session.sdkVersion)
        put(
            "device",
            buildJsonObject {
                put("model", shortString(session.deviceModel))
                put("osVersion", shortString(session.osVersion))
                session.locale?.takeIf { it.isNotBlank() }?.let { put("locale", shortString(it)) }
                session.totalRamBytes?.takeIf { it >= 0 }?.let { put("totalRamBytes", it) }
            },
        )
    }

    private fun headers(headers: List<Pair<String, String>>): JsonObject? {
        val merged = LinkedHashMap<String, String>()
        headers.forEach { (name, value) ->
            val key = name.lowercase()
            if (!HEADER_NAME.matches(key)) return@forEach
            merged[key] = merged[key]?.let { "$it, $value" } ?: value
        }
        if (merged.isEmpty()) return null
        return buildJsonObject {
            merged.entries.take(MAX_HEADERS).forEach { (name, value) ->
                put(name, if (name in REDACTED_HEADERS) REDACTED else value.take(MAX_HEADER_VALUE))
            }
        }
    }

    private fun body(body: DevNetworkBody?, maxBodyBytes: Int): JsonObject? {
        if (body == null || !body.isContent) return null
        val limit = maxBodyBytes.coerceIn(0, MAX_BODY_BYTES)
        val bytes = body.text.toByteArray(Charsets.UTF_8)
        val cut = bytes.size > limit
        val text = if (cut) String(bytes, 0, limit, Charsets.UTF_8).trimEnd('�') else body.text
        return buildJsonObject {
            put("text", text)
            put("truncated", body.truncated || cut)
            body.contentType?.let { put("contentType", it.take(MAX_SHORT_STRING)) }
            (body.originalBytes ?: bytes.size.toLong()).let { put("originalBytes", it) }
        }
    }

    private fun roundTo1(value: Double): Double = Math.round(value * 10) / 10.0
}
