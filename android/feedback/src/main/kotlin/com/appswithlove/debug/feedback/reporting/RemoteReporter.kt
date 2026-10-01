package com.appswithlove.debug.feedback.reporting

import android.content.Context
import android.os.SystemClock
import com.appswithlove.debug.api.extension.DevNetworkRecord
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import java.util.concurrent.Future
import java.util.concurrent.ScheduledExecutorService

/**
 * Records sessions, requests and metric samples into [buffer] for remote reporting. All work runs on
 * [executor], one task at a time, so callers never block on disk access.
 *
 * A session starts with the first foreground (or the first captured request, if earlier) and ends
 * when the app goes to the background; returning within [SESSION_TIMEOUT_MS] continues it.
 */
internal class RemoteReporter(
    private val context: Context,
    private val config: RemoteReportingConfig,
    private val buffer: ReportingBuffer,
    private val executor: ScheduledExecutorService,
    appUserId: String?,
    private val clock: () -> Long = System::currentTimeMillis,
    private val elapsedRealtime: () -> Long = SystemClock::elapsedRealtime,
    samplerFactory: ((ReportingMetricSample) -> Unit) -> ReportingMetricsSampler? = { onSample ->
        ReportingMetricsSampler(context, executor, onSample)
    },
    private val status: MutableStateFlow<ReportingStatus>? = null,
) {
    private val endpoint = config.endpoint.trimEnd('/')
    private val maxBodyBytes = config.maxBodyBytes.coerceIn(0, ReportingJson.MAX_BODY_BYTES)
    private val sampler = samplerFactory(::onMetric)
    private var userIdentifier = appUserId?.let { ReportingJson.userIdentifier(config.appKey, it) }
    private var session: ReportingSession? = null
    private var backgroundSince: Long? = null
    private var isForeground = false

    /** Off ("Send session data" switched off, or the service refused the key): nothing new is recorded. */
    @Volatile
    private var isRecording = true

    /** Seals sessions an earlier process left behind, so they go out with their own session object. */
    fun start(): Future<*> = executor.submit {
        buffer.load().forEach { buffer.seal(it.id, finish = true) }
        publish()
    }

    fun setRecording(on: Boolean): Future<*> = executor.submit {
        isRecording = on
        if (on && isForeground) sampler?.start() else sampler?.stop()
    }

    fun onForeground(): Future<*> = executor.submit {
        val current = session
        val since = backgroundSince
        backgroundSince = null
        isForeground = true
        if (current == null || (since != null && elapsedRealtime() - since >= SESSION_TIMEOUT_MS)) {
            current?.let { buffer.seal(it.id, finish = true) }
            newSession()
        } else if (current.endedAtMillis != null) {
            update(current.copy(endedAtMillis = null))
        }
        if (isRecording) sampler?.start()
        publish()
    }

    fun onBackground(): Future<*> = executor.submit {
        backgroundSince = elapsedRealtime()
        isForeground = false
        sampler?.stop()
        val current = session ?: return@submit
        update(current.copy(endedAtMillis = clock()))
        buffer.seal(current.id)
        publish()
    }

    fun onNetworkRecord(record: DevNetworkRecord) {
        // The SDK's own requests to the service are never reported.
        if (record.url == endpoint || record.url.startsWith("$endpoint/")) return
        if (!isRecording) return
        executor.execute {
            val json = ReportingJson.networkLog(record, config.captureBodies, maxBodyBytes) ?: return@execute
            buffer.append(currentSession().id, record.startedAtMillis, ReportingBuffer.EntryKind.Network, json)
            publish()
        }
    }

    fun setUserIdentifier(appUserId: String?): Future<*> = executor.submit {
        userIdentifier = appUserId?.let { ReportingJson.userIdentifier(config.appKey, it) }
        session?.let { update(it.copy(userIdentifier = userIdentifier)) }
    }

    /** Moves everything recorded so far into sealed batches. */
    fun flush(): Future<*> = executor.submit {
        session?.let { buffer.seal(it.id) }
        publish()
    }

    fun onMetric(sample: ReportingMetricSample) {
        if (!isRecording) return
        executor.execute {
            val json = ReportingJson.metric(sample) ?: return@execute
            buffer.append(currentSession().id, sample.timestampMillis, ReportingBuffer.EntryKind.Metric, json)
            publish()
        }
    }

    private fun publish() {
        val status = status ?: return
        val pending = buffer.pendingEntries()
        val sessionId = session?.id
        status.update { it.copy(pendingEntries = pending, sessionId = sessionId) }
    }

    private fun currentSession(): ReportingSession = session ?: newSession()

    private fun newSession(): ReportingSession =
        ReportingSession.create(context, config, userIdentifier, clock()).also(::update)

    private fun update(updated: ReportingSession) {
        session = updated
        buffer.putSession(updated)
    }

    companion object {
        const val SESSION_TIMEOUT_MS = 30L * 60 * 1000
    }
}
