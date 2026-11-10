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
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Executor
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

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
        val request = chain.request()
        val counter = NetworkRedactor.Counter()
        val startedAtMillis = System.currentTimeMillis()
        val url = redactor.url(request.url, counter)
        val requestHeaders = redactor.headers(request.headers, counter)
        val requestBody = bodyCapture.request(request.body, counter)
        val requestBytes = request.body?.contentLength()?.takeIf { it >= 0 }

        /** Redacts the bodies and stores the entry off the request path. */
        fun recordLater(response: Response?, durationMs: Long, error: Throwable?, responseBytes: Long?, responseBody: () -> CapturedBody?) {
            executor.execute {
                // Runs on the capture thread: an exception here would crash the app instead of failing a request.
                runCatching {
                    val capturedResponse = responseBody()
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
                        requestBody = requestBody(),
                        responseBody = capturedResponse,
                        error = error?.toString(),
                        redactedCount = counter.count,
                        isSlow = durationMs > config.slowRequestThresholdMs,
                    ).let(::record)
                }
            }
        }

        val startNanos = System.nanoTime()
        val response = try {
            chain.proceed(request)
        } catch (e: Exception) {
            recordLater(response = null, elapsedMs(startNanos), error = e, responseBytes = null) { null }
            throw e
        }
        val durationMs = elapsedMs(startNanos)
        val contentLength = response.body?.contentLength()?.takeIf { it >= 0 }
        return when (val capture = bodyCapture.response(response)) {
            is ResponseCapture.Ready -> {
                recordLater(response, durationMs, error = null, contentLength) { capture.body }
                response
            }
            ResponseCapture.ReadAlong -> {
                val body = bodyCapture.readAlong(response) { result ->
                    val responseBytes = contentLength ?: result.totalBytes.takeIf { result.isComplete }
                    recordLater(response, durationMs, error = null, responseBytes) { bodyCapture.response(response, result, counter) }
                }
                response.newBuilder().body(body).build()
            }
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

/** Requests waiting for redaction; when the app sends faster than they are redacted, the oldest are dropped. */
private const val CAPTURE_QUEUE_CAPACITY = 256

private val CAPTURE_EXECUTOR: Executor by lazy {
    ThreadPoolExecutor(
        1, 1, 0L, TimeUnit.MILLISECONDS,
        ArrayBlockingQueue(CAPTURE_QUEUE_CAPACITY),
        { runnable -> Thread(runnable, "awl-debug-network").apply { isDaemon = true } },
        ThreadPoolExecutor.DiscardOldestPolicy(),
    )
}

data class Log(
    val severity: DevLogSeverity,
    val message: String,
    val tag: String? = null,
    val throwable: Throwable? = null,
)
