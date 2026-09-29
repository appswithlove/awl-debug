package com.appswithlove.debug.feedback

import android.os.Build
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

private const val MAX_EXTRA_ENTRIES = 30
private const val MAX_EXTRA_KEY_LENGTH = 64
private const val MAX_EXTRA_VALUE_LENGTH = 500
private const val MAX_STRING_LENGTH = 200
private const val SCREEN_KEY = "screen"

internal data class DeviceInfo(
    val osVersion: String,
    val deviceModel: String,
    val locale: String,
) {
    companion object {
        fun current(): DeviceInfo = DeviceInfo(
            osVersion = Build.VERSION.RELEASE.orEmpty(),
            deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}",
            locale = Locale.getDefault().toLanguageTag(),
        )
    }
}

/** Builds the `metadata` part of the report; [extra] is read once when the report starts. */
internal fun buildMetadataJson(
    config: FeedbackConfig,
    device: DeviceInfo,
    extra: Map<String, String>,
    timestamp: Date,
): String {
    // The service rejects the whole report when a limit is exceeded, so everything is capped here.
    val cappedExtra = extra.entries
        .filter { (key, _) -> key.isNotBlank() }
        .map { (key, value) -> key.take(MAX_EXTRA_KEY_LENGTH) to value.take(MAX_EXTRA_VALUE_LENGTH) }
        .distinctBy { (key, _) -> key }
        .take(MAX_EXTRA_ENTRIES)
        .toMap()
    return JSONObject().apply {
        put("platform", "android")
        put("osVersion", device.osVersion.capped())
        put("deviceModel", device.deviceModel.capped())
        put("appVersion", config.appVersion.capped())
        put("buildNumber", config.buildNumber.capped())
        put("environment", config.environment.capped())
        // Only sent when set: services without support for these fields reject unknown keys.
        config.distribution?.let { put("distribution", it.wireValue) }
        put("locale", device.locale.capped())
        cappedExtra[SCREEN_KEY]?.let { put(SCREEN_KEY, it.capped()) }
        put("timestamp", isoUtc(timestamp))
        put("extra", JSONObject(cappedExtra))
        config.reporter?.takeIf { it.name.isNotBlank() }?.let { reporter ->
            put(
                "reporter",
                JSONObject().apply {
                    put("name", reporter.name.capped())
                    reporter.email?.takeIf { it.isNotBlank() }?.let { put("email", it.capped()) }
                },
            )
        }
    }.toString()
}

private fun String.capped(): String = take(MAX_STRING_LENGTH)

private fun isoUtc(date: Date): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    .apply { timeZone = TimeZone.getTimeZone("UTC") }
    .format(date)
