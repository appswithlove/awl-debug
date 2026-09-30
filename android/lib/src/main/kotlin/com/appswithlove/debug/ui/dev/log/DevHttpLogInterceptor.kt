package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.extension.toRecord
import com.appswithlove.debug.ui.dev.network.BodyCapture
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.NetworkLogStore
import com.appswithlove.debug.ui.dev.network.NetworkRedactor
import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/**
 * An OkHttp [Interceptor] that records every request and response for the Network module and
 * writes a one-line summary to the Logs module.
 *
 * Add it with `addInterceptor()` to see what the app sends, or with `addNetworkInterceptor()` to
 * also see headers added by OkHttp, such as cookies from the `CookieJar`.
 *
 * Values are redacted before they are stored: `Authorization`, `Proxy-Authorization`, `Cookie`,
 * `Set-Cookie` and userinfo in URLs always, everything else according to [DevNetworkConfig].
 * One-shot, duplex and streaming bodies are never read.
 *
 * @param config What to capture and redact.
 */
@Suppress("Unused")
class DevHttpLogInterceptor(
    private val config: DevNetworkConfig = DevNetworkConfig(),
) : Interceptor {

    private var store: NetworkLogStore = NetworkCollector.store
    private var logCollector: DevLogCollector = LogCollector.devLogCollector
    private val redactor = NetworkRedactor(config)
    private val bodyCapture = BodyCapture(config, redactor)

    init {
        store.onInterceptorCreated()
    }

    internal constructor(
        config: DevNetworkConfig,
        store: NetworkLogStore,
        logCollector: DevLogCollector,
    ) : this(config) {
        this.store = store
        this.logCollector = logCollector
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

        fun entry(response: Response?, durationMs: Long, error: Throwable?): NetworkEntry {
            val responseBody = response?.let { bodyCapture.response(it, counter) }
            val responseHeaders = response?.let { redactor.headers(it.headers, counter) }.orEmpty()
            return NetworkEntry(
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
                responseBytes = response?.body?.contentLength()?.takeIf { it >= 0 } ?: responseBody?.originalBytes,
                requestHeaders = requestHeaders,
                responseHeaders = responseHeaders,
                requestBody = requestBody,
                responseBody = responseBody,
                error = error?.toString(),
                redactedCount = counter.count,
                isSlow = durationMs > config.slowRequestThresholdMs,
            )
        }

        val startNanos = System.nanoTime()
        val response = try {
            chain.proceed(request)
        } catch (e: Exception) {
            record(entry(response = null, durationMs = elapsedMs(startNanos), error = e))
            throw e
        }
        record(entry(response, elapsedMs(startNanos), error = null))
        return response
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

data class Log(
    val severity: DevLogSeverity,
    val message: String,
    val tag: String? = null,
    val throwable: Throwable? = null,
)
