package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.ui.dev.log.LogCollector.devLogCollector
import okhttp3.Headers
import okhttp3.Interceptor
import okhttp3.RequestBody
import okhttp3.Response
import okio.Buffer
import okio.Sink
import okio.Timeout
import okio.buffer
import java.io.IOException

/**
 * An OkHttp [Interceptor].
 *
 * To function, this interceptor must be added to your `OkHttpClient`
 * instance using the `.addInterceptor()` method.
 *
 * This interceptor captures all outgoing HTTP requests and their corresponding
 * responses. It then formats this network traffic information (including
 * status codes, headers, and bodies) and passes it to the provided
 * [DevLogCollector] for storage or display.
 *
 * The values of `Authorization`, `Proxy-Authorization`, `Cookie` and `Set-Cookie`
 * are always replaced with `[REDACTED]`. One-shot and duplex request bodies are
 * never read, and captured bodies are cut off after [maxBodyBytes].
 *
 * @param logCollector The collector service that will receive the formatted
 * [Log] objects.
 * @param redactHeaders Additional header names whose values are redacted
 * (case-insensitive).
 * @param maxBodyBytes Maximum number of bytes captured per request or response body.
 */
@Suppress("Unused")
class DevHttpLogInterceptor @JvmOverloads constructor(
    private val logCollector: DevLogCollector = devLogCollector,
    redactHeaders: Set<String> = emptySet(),
    private val maxBodyBytes: Long = DEFAULT_MAX_BODY_BYTES,
) : Interceptor {

    private val redactedHeaderNames: Set<String> =
        (ALWAYS_REDACTED_HEADERS + redactHeaders).mapTo(mutableSetOf()) { it.lowercase() }

    @Throws(IOException::class)
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        val requestMessage = "--> ${request.method} ${request.url}\n" +
                "Headers: \n${request.headers.toRedactedString()}\n" +
                "Body: ${request.body.toFormattedString()}\n" +
                "--> END ${request.method}"

        // Log the request as DEBUG
        logCollector.log(
            Log(DevLogSeverity.DEBUG, requestMessage)
        )

        // Determine Severity from Response
        val startTime = System.nanoTime()
        try {
            val response = chain.proceed(request)
            val durationMs = (System.nanoTime() - startTime) / 1_000_000L

            // Determine severity from the response code
            val severity = when (response.code) {
                in 200..299 -> DevLogSeverity.INFO
                in 300..399 -> DevLogSeverity.INFO
                in 400..499 -> DevLogSeverity.WARN
                else -> DevLogSeverity.ERROR // 5xx and others
            }

            val responseMessage =
                "<-- ${response.code} ${response.message} ${response.request.url} (${durationMs}ms)\n" +
                        "Headers: \n${response.headers.toRedactedString()}\n" +
                        "Body: ${response.toFormattedBody()}\n" +
                        "<-- END HTTP"

            logCollector.log(
                Log(severity, responseMessage)
            )
            return response

        } catch (e: Exception) {
            val durationMs = (System.nanoTime() - startTime) / 1_000_000L
            val errorMessage = "<-- HTTP FAILED: $e (${durationMs}ms)"
            logCollector.log(
                Log(DevLogSeverity.ERROR, errorMessage)
            )
            throw e
        }
    }

    private fun Headers.toRedactedString(): String = buildString {
        for (index in 0 until size) {
            val name = name(index)
            val value = if (name.lowercase() in redactedHeaderNames) REDACTED else value(index)
            append(name).append(": ").append(value).append('\n')
        }
    }

    private fun RequestBody?.toFormattedString(): String {
        if (this == null) return "(no body)"
        if (isOneShot() || isDuplex()) return "(one-shot body, not captured)"
        return try {
            val contentLength = contentLength()
            if (contentLength > MAX_READABLE_REQUEST_BYTES) {
                return "($contentLength bytes, not captured)"
            }
            val sink = CappedSink(maxBodyBytes)
            sink.buffer().use { writeTo(it) }
            sink.captured.readUtf8().withTruncationNote(sink.totalBytes)
        } catch (e: IOException) {
            " (body could not be read: ${e.message})"
        }
    }

    private fun Response.toFormattedBody(): String {
        val body = peekBody(maxBodyBytes + 1)
        val bytes = body.bytes()
        if (bytes.size <= maxBodyBytes) return String(bytes, Charsets.UTF_8)
        val originalBytes = this.body?.contentLength()?.takeIf { it >= 0 }
        return String(bytes, 0, maxBodyBytes.toInt(), Charsets.UTF_8)
            .withTruncationNote(originalBytes ?: -1L)
    }

    private fun String.withTruncationNote(totalBytes: Long): String = when {
        totalBytes in 0..maxBodyBytes -> this
        totalBytes > maxBodyBytes -> "$this\n(truncated, $totalBytes bytes total)"
        else -> "$this\n(truncated after $maxBodyBytes bytes)"
    }

    /** Keeps the first [limit] bytes written to it and only counts the rest. */
    private class CappedSink(private val limit: Long) : Sink {
        val captured = Buffer()
        var totalBytes = 0L
            private set

        override fun write(source: Buffer, byteCount: Long) {
            val bytesToKeep = minOf(byteCount, limit - captured.size).coerceAtLeast(0L)
            source.read(captured, bytesToKeep)
            source.skip(byteCount - bytesToKeep)
            totalBytes += byteCount
        }

        override fun flush() = Unit
        override fun timeout(): Timeout = Timeout.NONE
        override fun close() = Unit
    }

    companion object {
        const val DEFAULT_MAX_BODY_BYTES: Long = 256L * 1024
        private const val MAX_READABLE_REQUEST_BYTES: Long = 1024L * 1024
        private const val REDACTED = "[REDACTED]"
        private val ALWAYS_REDACTED_HEADERS =
            setOf("Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie")
    }
}

data class Log(
    val severity: DevLogSeverity,
    val message: String,
    val tag: String? = null,
    val throwable: Throwable? = null,
)
