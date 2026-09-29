package com.appswithlove.debug.feedback.queue

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.util.Log
import com.appswithlove.debug.feedback.FeedbackClient
import com.appswithlove.debug.feedback.FeedbackPart
import com.appswithlove.debug.feedback.FeedbackReport
import com.appswithlove.debug.feedback.SendError
import com.appswithlove.debug.feedback.SendResult
import com.appswithlove.debug.feedback.isRetryable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException

private const val LOG_TAG = "FeedbackQueue"
private const val REPORT_FILE = "report.json"
private const val TMP_SUFFIX = ".tmp"
private const val FORMAT_VERSION = 1
private const val MAX_REPORTS = 20
private const val MAX_BYTES = 50L * 1024 * 1024
private const val MIN_BACKOFF_MS = 30_000L
private const val MAX_BACKOFF_MS = 60 * 60_000L

internal sealed interface SubmitResult {
    data object Sent : SubmitResult
    data object Queued : SubmitResult
    data class Failed(val error: SendError) : SubmitResult
}

/**
 * Sends reports and keeps the ones that failed for a reason worth retrying (network, timeout, 5xx, 429)
 * in [directory], one folder per report. Retries back off from 30 s to 1 h and respect `Retry-After`;
 * at most [maxReports] reports or [maxBytes] are kept, the oldest are dropped first.
 */
internal class FeedbackQueue(
    private val directory: File,
    private val client: FeedbackClient = FeedbackClient(),
    private val clock: () -> Long = System::currentTimeMillis,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val maxReports: Int = MAX_REPORTS,
    private val maxBytes: Long = MAX_BYTES,
) {
    private val mutex = Mutex()
    private val pending = MutableStateFlow(0)
    private var timer: Job? = null

    /** Number of reports waiting for another attempt. */
    val pendingCount: StateFlow<Int> = pending.asStateFlow()

    /** Sends [report] once; queues it when the failure is worth retrying. */
    suspend fun submit(report: FeedbackReport): SubmitResult = when (val result = client.send(report)) {
        is SendResult.Success -> SubmitResult.Sent
        is SendResult.Failure -> if (result.error.isRetryable && enqueue(report, result.error)) {
            scheduleTimer()
            SubmitResult.Queued
        } else {
            SubmitResult.Failed(result.error)
        }
    }

    /**
     * Retries queued reports in order. With [ignoreBackoff] every report goes out unless the service asked
     * to wait (`Retry-After`); otherwise only reports whose backoff has passed.
     */
    suspend fun retry(ignoreBackoff: Boolean) = mutex.withLock {
        withContext(Dispatchers.IO) {
            // Leftovers of writes interrupted by a process death.
            directory.listFiles().orEmpty()
                .filter { it.name.endsWith(TMP_SUFFIX) || !File(it, REPORT_FILE).isFile }
                .forEach { it.deleteRecursively() }
            for (entry in entries()) {
                val now = clock()
                if ((if (ignoreBackoff) entry.notBefore else entry.nextAttemptAt) > now) continue
                val report = entry.readReport()
                if (report == null) {
                    entry.dir.deleteRecursively()
                    continue
                }
                when (val result = client.send(report)) {
                    is SendResult.Success -> entry.dir.deleteRecursively()
                    is SendResult.Failure -> if (result.error.isRetryable) {
                        entry.recordFailure(result.error, now)
                        // Still offline: the remaining reports would fail the same way.
                        if (result.error == SendError.Network) break
                    } else {
                        Log.w(LOG_TAG, "Dropping queued report ${report.idempotencyKey}: ${result.error}")
                        entry.dir.deleteRecursively()
                    }
                }
            }
            pending.value = entries().size
        }
    }

    /** Runs [retry] in the background and schedules the next due attempt. */
    fun retryInBackground(ignoreBackoff: Boolean) {
        scope.launch {
            retry(ignoreBackoff)
            scheduleTimer()
        }
    }

    private suspend fun enqueue(report: FeedbackReport, error: SendError): Boolean = mutex.withLock {
        withContext(Dispatchers.IO) {
            try {
                val size = report.parts.sumOf { it.bytes.size.toLong() } + report.text.length + report.metadataJson.length
                if (size > maxBytes) return@withContext false
                directory.mkdirs()
                val tmp = File(directory, report.idempotencyKey + TMP_SUFFIX).apply { deleteRecursively(); mkdirs() }
                val parts = JSONArray()
                report.parts.forEachIndexed { index, part ->
                    val fileName = "part-$index"
                    File(tmp, fileName).writeBytes(part.bytes)
                    parts.put(JSONObject().put("name", part.name).put("fileName", part.fileName).put("mimeType", part.mimeType).put("file", fileName))
                }
                val now = clock()
                val json = JSONObject()
                    .put("version", FORMAT_VERSION)
                    .put("idempotencyKey", report.idempotencyKey)
                    .put("endpoint", report.endpoint)
                    .put("appKey", report.appKey)
                    .put("text", report.text)
                    .put("metadata", report.metadataJson)
                    .put("createdAt", now)
                    .put("parts", parts)
                File(tmp, REPORT_FILE).writeText(json.withSchedule(attempts = 1, error, now).toString())
                val target = File(directory, report.idempotencyKey)
                target.deleteRecursively()
                if (!tmp.renameTo(target)) throw IOException("Cannot move $tmp to $target")
                evictOldest()
                pending.value = entries().size
                true
            } catch (e: IOException) {
                Log.w(LOG_TAG, "Cannot queue report", e)
                false
            }
        }
    }

    private fun evictOldest() {
        val all = entries().toMutableList()
        var totalBytes = all.sumOf { it.sizeBytes() }
        while (all.size > maxReports || totalBytes > maxBytes) {
            val oldest = all.removeAt(0)
            totalBytes -= oldest.sizeBytes()
            oldest.dir.deleteRecursively()
        }
    }

    private suspend fun scheduleTimer() {
        val nextAt = mutex.withLock { withContext(Dispatchers.IO) { entries().minOfOrNull { it.nextAttemptAt } } } ?: return
        synchronized(this) {
            timer?.cancel()
            timer = scope.launch {
                delay((nextAt - clock()).coerceAtLeast(0))
                retry(ignoreBackoff = false)
                scheduleTimer()
            }
        }
    }

    /** Queued reports, oldest first. */
    private fun entries(): List<Entry> = directory.listFiles().orEmpty()
        .filter { it.isDirectory && !it.name.endsWith(TMP_SUFFIX) }
        .mapNotNull { dir ->
            val json = try {
                JSONObject(File(dir, REPORT_FILE).readText())
            } catch (_: IOException) {
                null
            } catch (_: JSONException) {
                null
            }
            json?.let { Entry(dir, it) }
        }
        .sortedBy { it.createdAt }

    private class Entry(val dir: File, val json: JSONObject) {
        val createdAt: Long get() = json.optLong("createdAt")
        val nextAttemptAt: Long get() = json.optLong("nextAttemptAt")
        val notBefore: Long get() = json.optLong("notBefore")

        fun sizeBytes(): Long = dir.listFiles().orEmpty().sumOf { it.length() }

        fun readReport(): FeedbackReport? = try {
            val parts = json.getJSONArray("parts")
            FeedbackReport(
                idempotencyKey = json.getString("idempotencyKey"),
                endpoint = json.getString("endpoint"),
                appKey = json.getString("appKey"),
                text = json.getString("text"),
                metadataJson = json.getString("metadata"),
                parts = (0 until parts.length()).map { index ->
                    val part = parts.getJSONObject(index)
                    FeedbackPart(
                        name = part.getString("name"),
                        fileName = part.getString("fileName"),
                        mimeType = part.getString("mimeType"),
                        bytes = File(dir, part.getString("file")).readBytes(),
                    )
                },
            )
        } catch (e: JSONException) {
            Log.w(LOG_TAG, "Unreadable queued report ${dir.name}", e)
            null
        } catch (e: IOException) {
            Log.w(LOG_TAG, "Unreadable queued report ${dir.name}", e)
            null
        }

        fun recordFailure(error: SendError, now: Long) {
            json.withSchedule(attempts = json.optInt("attempts") + 1, error, now)
            val tmp = File(dir, REPORT_FILE + TMP_SUFFIX)
            tmp.writeText(json.toString())
            tmp.renameTo(File(dir, REPORT_FILE))
        }
    }

    companion object {
        @Volatile
        private var shared: FeedbackQueue? = null

        /**
         * The process-wide queue in `files/awl-debug/feedback-queue/`. The first call retries at once
         * (app start) and retries again whenever a network becomes available.
         */
        fun shared(context: Context): FeedbackQueue = shared ?: synchronized(this) {
            shared ?: create(context.applicationContext).also { shared = it }
        }

        private fun create(appContext: Context): FeedbackQueue {
            val queue = FeedbackQueue(File(appContext.filesDir, "awl-debug/feedback-queue"))
            val connectivity = appContext.getSystemService(ConnectivityManager::class.java)
            try {
                // Also called right away when a network is up, which covers the retry at app start.
                connectivity?.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) = queue.retryInBackground(ignoreBackoff = true)
                })
            } catch (e: SecurityException) {
                Log.w(LOG_TAG, "No network callbacks, retrying on app start and foreground only", e)
            }
            queue.retryInBackground(ignoreBackoff = true)
            return queue
        }
    }
}

/** Schedules the next attempt: 30 s doubling to 1 h, never before `Retry-After`. */
private fun JSONObject.withSchedule(attempts: Int, error: SendError, now: Long): JSONObject {
    val backoff = (MIN_BACKOFF_MS shl (attempts - 1).coerceIn(0, 7)).coerceAtMost(MAX_BACKOFF_MS)
    val notBefore = (error as? SendError.RateLimited)?.retryAfterSeconds?.let { now + it * 1000L } ?: 0L
    return put("attempts", attempts)
        .put("nextAttemptAt", maxOf(now + backoff, notBefore))
        .put("notBefore", notBefore)
}
