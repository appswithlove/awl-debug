package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.extension.toRecord
import com.appswithlove.debug.ui.dev.network.BodyCapture
import com.appswithlove.debug.ui.dev.network.CapturedBody
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.NetworkLogStore
import com.appswithlove.debug.ui.dev.network.NetworkRedactor
import com.appswithlove.debug.ui.dev.network.ResponseCapture
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/**
 * An OkHttp [Interceptor] that records every request and response for the Network module and
 * writes a one-line summary to the Logs module.
 *
 * Add it with `addInterceptor()` to see what the app sends, or with `addNetworkInterceptor()` to
 * also see headers added by OkHttp, such as cookies from the `CookieJar`.
 *
 * Values are redacted before they are stored: `Authorization`, `Proxy-Authorization`, `Cookie`,
 * `Set-Cookie` and userinfo in URLs always, everything else according to [DevNetworkConfig].
 * One-shot, duplex and streaming bodies are never read. Other response bodies are captured while the
 * app reads them, so the request is stored once the app read the body to the end or closed it.
 * WebSockets are recorded with their handshake when added with `addInterceptor()`; OkHttp does not
 * call network interceptors for them.
 *
 * @param config What to capture and redact.
 */
@Suppress("Unused")
class DevHttpLogInterceptor(
    private val config: DevNetworkConfig = DevNetworkConfig(),
) : Interceptor {

    private var store: NetworkLogStore = NetworkCollector.store
    private var logCollector: DevLogCollector = LogCollector.devLogCollector
    private var executor: Executor = CAPTURE_EXECUTOR
    private val redactor = NetworkRedactor(config)
    private val bodyCapture = BodyCapture(config, redactor)

    init {
        store.onInterceptorCreated()
    }

    internal constructor(
        config: DevNetworkConfig,
        store: NetworkLogStore,
        logCollector: DevLogCollector,
        executor: Executor = CAPTURE_EXECUTOR,
    ) : this(config) {
        this.store = store
        this.logCollector = logCollector
        this.executor = executor
        store.onInterceptorCreated()
    }

    @Throws(IOException::class)
    override fun intercept(chain: Interceptor.Chain): Response {
        val capture = RequestCapture(chain.request())
        val startNanos = System.nanoTime()
        val response = try {
            chain.proceed(capture.request)
        } catch (e: Throwable) {
            capture.recordLater(response = null, elapsedMs(startNanos), error = e, responseBytes = null) { null }
            throw e
        }
        val durationMs = elapsedMs(startNanos)
        val contentLength = response.body?.contentLength()?.takeIf { it >= 0 }
        return when (val responseCapture = bodyCapture.response(response)) {
            is ResponseCapture.Ready -> {
                capture.recordLater(response, durationMs, error = null, contentLength) { responseCapture.body }
                response
            }
            ResponseCapture.ReadAlong -> {
                val body = bodyCapture.readAlong(response) { result ->
                    val responseBytes = contentLength ?: result.totalBytes.takeIf { result.isComplete }
                    // Like on iOS, the duration includes the body, so a slow body counts as slow.
                    val bodyDurationMs = elapsedMs(startNanos)
                    capture.recordLater(response, bodyDurationMs, result.error, responseBytes, result.bytes.size.toLong()) {
                        bodyCapture.response(response, result, capture.counter)
                    }
                }
                response.newBuilder().body(body).build()
            }
        }
    }

    /** What is captured of a request before it is sent; [recordLater] adds the outcome and stores it. */
    private inner class RequestCapture(val request: Request) {
        val counter = NetworkRedactor.Counter()
        private val startedAtMillis = System.currentTimeMillis()
        private val url = redactor.url(request.url, counter)
        private val requestHeaders = redactor.headers(request.headers, counter)
        private val requestBody = bodyCapture.request(request.body, counter)
        private val requestBytes = request.body?.contentLength()?.takeIf { it >= 0 }
        private val requestHeldBytes = requestBytes?.takeIf { it <= BodyCapture.MAX_READ_BYTES } ?: 0L

        /** Redacts the bodies and stores the entry off the request path. */
        fun recordLater(
            response: Response?,
            durationMs: Long,
            error: Throwable?,
            responseBytes: Long?,
            responseHeldBytes: Long = 0L,
            responseBody: () -> CapturedBody?,
        ) = enqueue(requestHeldBytes + responseHeldBytes) { withBodies ->
            val capturedResponse = if (withBodies) responseBody() else QUEUE_FULL_BODY.takeIf { response?.body != null }
            NetworkEntry(
                id = store.newId(),
                startedAtMillis = startedAtMillis,
                method = request.method,
                url = url,
                host = request.url.host,
                path = request.url.encodedPath,
                status = response?.code ?: 0,
                reason = response?.message?.ifEmpty { null },
                durationMs = durationMs,
                requestBytes = requestBytes,
                responseBytes = responseBytes ?: capturedResponse?.originalBytes,
                requestHeaders = requestHeaders,
                responseHeaders = response?.let { redactor.headers(it.headers, counter) }.orEmpty(),
                requestBody = if (withBodies) requestBody() else QUEUE_FULL_BODY.takeIf { request.body != null },
                responseBody = capturedResponse,
                error = error?.toString(),
                redactedCount = counter.count,
                isSlow = durationMs > config.slowRequestThresholdMs,
            )
        }
    }

    /**
     * Builds and stores an entry on the capture thread. [heldBytes] is what the job keeps in memory until it runs;
     * beyond [MAX_PENDING_BYTES] waiting, [makeEntry] is asked to leave the bodies out.
     */
    private fun enqueue(heldBytes: Long, makeEntry: (withBodies: Boolean) -> NetworkEntry) {
        val withBodies = PENDING_BYTES.addAndGet(heldBytes) <= MAX_PENDING_BYTES
        if (!withBodies) PENDING_BYTES.addAndGet(-heldBytes)
        val reservedBytes = if (withBodies) heldBytes else 0L
        val job = Runnable {
            // Runs on the capture thread: an exception here would crash the app instead of failing a request.
            runCatching { record(makeEntry(withBodies)) }
            PENDING_BYTES.addAndGet(-reservedBytes)
        }
        try {
            executor.execute(job)
        } catch (_: RejectedExecutionException) {
            // More requests waiting than the capture thread keeps up with: this one is not stored.
            PENDING_BYTES.addAndGet(-reservedBytes)
        }
    }

    @OptIn(AwlDebugInternalApi::class)
    private fun record(entry: NetworkEntry) {
        store.add(entry)
        AwlDebugExtensions.publishNetworkRecord(entry.toRecord())
        logCollector.log(Log(entry.severity(), entry.summary(), tag = LOG_TAG))
    }

    private fun NetworkEntry.severity() = when (status) {
        in 200..399 -> DevLogSeverity.INFO
        in 400..499 -> DevLogSeverity.WARN
        else -> DevLogSeverity.ERROR // 5xx, failures and others
    }

    private fun NetworkEntry.summary(): String {
        val status = if (isFailed) "Failed" else status.toString()
        return "$method $status ${durationMs}ms $url" + (error?.let { " ($it)" } ?: "")
    }

    private fun elapsedMs(startNanos: Long) = (System.nanoTime() - startNanos) / 1_000_000L
}

private const val LOG_TAG = "HTTP"

/** Requests waiting for redaction; beyond this the newest are not stored. */
private const val CAPTURE_QUEUE_CAPACITY = 1_000

/** Body bytes the waiting requests may hold; beyond this they are stored without bodies. */
private const val MAX_PENDING_BYTES = 16L * 1024 * 1024
private val PENDING_BYTES = AtomicLong()
private val QUEUE_FULL_BODY = CapturedBody("(not captured, too many requests waiting)", contentType = null, isContent = false)

private val CAPTURE_EXECUTOR: Executor by lazy {
    ThreadPoolExecutor(
        1, 1, 0L, TimeUnit.MILLISECONDS,
        ArrayBlockingQueue(CAPTURE_QUEUE_CAPACITY),
        { runnable -> Thread(runnable, "awl-debug-network").apply { isDaemon = true } },
        ThreadPoolExecutor.AbortPolicy(),
    )
}

data class Log(
    val severity: DevLogSeverity,
    val message: String,
    val tag: String? = null,
    val throwable: Throwable? = null,
)
