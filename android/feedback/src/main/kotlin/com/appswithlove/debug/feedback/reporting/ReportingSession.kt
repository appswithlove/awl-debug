package com.appswithlove.debug.feedback.reporting

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.appswithlove.debug.feedback.BuildConfig
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put
import java.util.Locale
import java.util.UUID

/** One app session as sent in `session`, plus what the buffer needs to finish it later. */
internal data class ReportingSession(
    val id: String,
    val startedAtMillis: Long,
    val endedAtMillis: Long?,
    val userIdentifier: String?,
    val appVersion: String,
    val buildNumber: String,
    val environment: String,
    val distribution: String,
    val sdkVersion: String,
    val deviceModel: String,
    val osVersion: String,
    val locale: String?,
    val totalRamBytes: Long?,
) {
    /** Stored form: the wire object plus millis, so a later process can finish the session. */
    fun toStoredJson(): JsonObject = buildJsonObject {
        put("session", ReportingJson.session(this@ReportingSession))
        put("startedAtMillis", startedAtMillis)
        endedAtMillis?.let { put("endedAtMillis", it) }
    }

    companion object {
        fun fromStoredJson(stored: JsonObject): ReportingSession? = try {
            val session = stored["session"] as JsonObject
            val device = session["device"] as JsonObject
            fun JsonObject.string(key: String) = this[key]?.jsonPrimitive?.content
            ReportingSession(
                id = session.string("id")!!,
                startedAtMillis = stored["startedAtMillis"]!!.jsonPrimitive.long,
                endedAtMillis = stored["endedAtMillis"]?.jsonPrimitive?.longOrNull,
                userIdentifier = session.string("userIdentifier"),
                appVersion = session.string("appVersion")!!,
                buildNumber = session.string("buildNumber")!!,
                environment = session.string("environment")!!,
                distribution = session.string("distribution")!!,
                sdkVersion = session.string("sdkVersion")!!,
                deviceModel = device.string("model")!!,
                osVersion = device.string("osVersion")!!,
                locale = device.string("locale"),
                totalRamBytes = device["totalRamBytes"]?.jsonPrimitive?.longOrNull,
            )
        } catch (_: Exception) {
            null
        }

        fun create(
            context: Context,
            config: RemoteReportingConfig,
            userIdentifier: String?,
            nowMillis: Long,
        ): ReportingSession {
            val packageInfo = try {
                context.packageManager.getPackageInfo(context.packageName, 0)
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
            val buildNumber = when {
                packageInfo == null -> null
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> packageInfo.longVersionCode
                else -> @Suppress("DEPRECATION") packageInfo.versionCode.toLong()
            }
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val totalRam = activityManager?.let { manager ->
                ActivityManager.MemoryInfo().also { manager.getMemoryInfo(it) }.totalMem.takeIf { it > 0 }
            }
            return ReportingSession(
                id = UUID.randomUUID().toString(),
                startedAtMillis = nowMillis,
                endedAtMillis = null,
                userIdentifier = userIdentifier,
                appVersion = packageInfo?.versionName.orEmpty(),
                buildNumber = buildNumber?.toString().orEmpty(),
                environment = config.environment,
                distribution = config.distribution.wireValue,
                sdkVersion = BuildConfig.SDK_VERSION,
                deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}",
                osVersion = Build.VERSION.RELEASE.orEmpty(),
                locale = Locale.getDefault().toLanguageTag(),
                totalRamBytes = totalRam,
            )
        }
    }
}

/** One metric sample; `null` means not measured and is left out of the batch. */
internal data class ReportingMetricSample(
    val timestampMillis: Long,
    val cpuPercent: Double? = null,
    val ramBytes: Long? = null,
    val batteryPercent: Int? = null,
    val uiFreezeMs: Long? = null,
)
