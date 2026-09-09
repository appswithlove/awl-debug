package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.ui.dev.log.LogCollector.devLogCollector
import okhttp3.Interceptor
import okhttp3.Response
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
 * @param logCollector The collector service that will receive the formatted
 * [Log] objects.
 */
@Suppress("Unused")
class DevHttpLogInterceptor(
    private val logCollector: DevLogCollector = devLogCollector,
) : Interceptor {

    @Throws(IOException::class)
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        val requestMessage = "--> ${request.method} ${request.url}\n" +
                "Headers: \n${request.headers}\n" +
                "Body: ${request.body?.toFormattedString() ?: "(no body)"}\n" +
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

            val responseBody = response.peekBody(1024 * 1024)
            val responseMessage =
                "<-- ${response.code} ${response.message} ${response.request.url} (${durationMs}ms)\n" +
                        "Headers: \n${response.headers}\n" +
                        "Body: ${responseBody.string()}\n" +
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

    private fun okhttp3.RequestBody?.toFormattedString(): String {
        if (this == null) return " (no body)"
        return try {
            val buffer = okio.Buffer()
            this.writeTo(buffer)
            buffer.readUtf8()
        } catch (e: IOException) {
            " (body could not be read: ${e.message})"
        }
    }
}

data class Log(
    val severity: DevLogSeverity,
    val message: String
)
