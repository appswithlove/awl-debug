package com.appswithlove.debug.feedback.reporting

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update
import java.io.File
import java.io.IOException
import java.util.concurrent.Callable
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.ScheduledExecutorService

/** What the panel row shows. */
internal data class ReportingStatus(
    val isConfigured: Boolean = false,
    val isStoreBuild: Boolean = false,
    val isSendingEnabled: Boolean = true,
    /** 401 or 403: nothing is sent until the next app start. */
    val stoppedStatus: Int? = null,
    /** Last batch the service rejected for good (400, 413, 422, …). */
    val rejectedStatus: Int? = null,
    val isRetrying: Boolean = false,
    val isWaitingForUnmeteredNetwork: Boolean = false,
    val lastSentMillis: Long? = null,
    val pendingEntries: Long = 0,
    val sessionId: String? = null,
) {
    val isOn: Boolean get() = !isStoreBuild && isSendingEnabled && stoppedStatus == null
}

/**
 * Sends sealed batches oldest first on its own thread. The [buffer] is only touched on
 * [bufferExecutor], the thread that owns it.
 *
 * A batch file never changes once sealed, so every retry sends the same `batchId` with the same bytes.
 * Network errors, 5xx and 429 keep the batch and back off from 30 s to 1 h, never before `Retry-After`.
 */
internal class ReportingUploader(
    private val bufferExecutor: ScheduledExecutorService,
    private val buffer: ReportingBuffer,
    private val sender: ReportingSender,
    private val status: MutableStateFlow<ReportingStatus>,
    private val canSend: () -> Boolean = { true },
    private val clock: () -> Long = System::currentTimeMillis,
    private val onStopped: () -> Unit = {},
    private val uploadExecutor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "awl-debug-reporting-upload").apply { isDaemon = true }
    },
) {
    // Only used on the upload thread.
    private var failedAttempts = 0
    private var nextAttemptAt = 0L
    private var notBefore = 0L

    /** With [ignoreBackoff] (app to background, "Flush now", network back) only `Retry-After` still holds. */
    fun upload(ignoreBackoff: Boolean): Future<*> = uploadExecutor.submit { uploadPending(ignoreBackoff) }

    private fun uploadPending(ignoreBackoff: Boolean) {
        try {
            val current = status.value
            if (!current.isOn) return
            val now = clock()
            if (now < notBefore || (!ignoreBackoff && now < nextAttemptAt)) return
            val allowed = canSend()
            status.update { it.copy(isWaitingForUnmeteredNetwork = !allowed) }
            if (!allowed) return
            for (batch in onBuffer { buffer.sealedBatches() }) {
                if (!send(batch)) break
            }
        } finally {
            refreshPending()
        }
    }

    /** Returns `false` when the rest has to wait. */
    private fun send(batch: File): Boolean {
        val bytes = try {
            batch.readBytes()
        } catch (_: IOException) {
            return true // dropped from the buffer meanwhile
        }
        return when (val result = sender.send(bytes)) {
            SendResult.Accepted -> {
                onBuffer { buffer.deleteBatch(batch) }
                failedAttempts = 0
                nextAttemptAt = 0
                notBefore = 0
                status.update { it.copy(lastSentMillis = clock(), isRetrying = false, rejectedStatus = null) }
                true
            }
            is SendResult.Rejected -> {
                onBuffer { buffer.deleteBatch(batch) }
                status.update { it.copy(rejectedStatus = result.status) }
                true
            }
            is SendResult.Stopped -> {
                status.update { it.copy(stoppedStatus = result.status, isRetrying = false) }
                onStopped()
                false
            }
            is SendResult.Retry -> {
                val now = clock()
                failedAttempts++
                val backoff = (MIN_BACKOFF_MS shl (failedAttempts - 1).coerceAtMost(7)).coerceAtMost(MAX_BACKOFF_MS)
                notBefore = result.retryAfterMillis?.let { now + it } ?: 0
                nextAttemptAt = maxOf(now + backoff, notBefore)
                status.update { it.copy(isRetrying = true) }
                false
            }
        }
    }

    private fun refreshPending() {
        val pending = try {
            onBuffer { buffer.pendingEntries() }
        } catch (_: Exception) {
            return
        }
        status.update { it.copy(pendingEntries = pending) }
    }

    private fun <T> onBuffer(block: () -> T): T = bufferExecutor.submit(Callable(block)).get()

    fun shutdown() {
        uploadExecutor.shutdownNow()
    }

    companion object {
        const val MIN_BACKOFF_MS = 30_000L
        const val MAX_BACKOFF_MS = 60 * 60_000L
    }
}
