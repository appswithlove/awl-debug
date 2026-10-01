package com.appswithlove.debug.feedback.reporting

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException
import java.util.concurrent.TimeUnit

/** How the service answered one batch. */
internal sealed interface SendResult {
    /** Stored or already known (`duplicate`): the batch can go. */
    data object Accepted : SendResult

    /** 400, 413, 422 and other 4xx: sending again would fail again, so the batch is dropped. */
    data class Rejected(val status: Int) : SendResult

    /** 401 or 403: stop sending until the next app start. */
    data class Stopped(val status: Int) : SendResult

    /** Network error, 5xx or 429: keep the batch and try again later. */
    data class Retry(val retryAfterMillis: Long?) : SendResult
}

/**
 * Posts gzip-compressed batches to `POST /v1/sessions/batch`. Uses its own [OkHttpClient] without the
 * app's interceptors, so these requests never show up in the Network module or in a batch.
 */
internal class ReportingSender(
    endpoint: String,
    private val appKey: String,
    private val client: OkHttpClient = defaultClient(),
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val url = endpoint.trimEnd('/') + PATH

    fun send(gzippedBatch: ByteArray): SendResult {
        val request = Request.Builder()
            .url(url)
            .header("X-App-Key", appKey)
            .header("Content-Encoding", "gzip")
            .post(gzippedBatch.toRequestBody(JSON))
            .build()
        return try {
            client.newCall(request).execute().use(::result)
        } catch (_: IOException) {
            SendResult.Retry(retryAfterMillis = null)
        }
    }

    private fun result(response: Response): SendResult = when (val status = response.code) {
        in 200..299 -> SendResult.Accepted
        401, 403 -> SendResult.Stopped(status)
        429 -> SendResult.Retry(retryAfterMillis(response))
        in 500..599 -> SendResult.Retry(retryAfterMillis(response))
        else -> SendResult.Rejected(status)
    }

    /** `Retry-After` as seconds or HTTP date. */
    private fun retryAfterMillis(response: Response): Long? {
        val value = response.header("Retry-After") ?: return null
        value.trim().toLongOrNull()?.let { return (it * 1000).coerceAtLeast(0) }
        return response.headers.getDate("Retry-After")?.let { (it.time - clock()).coerceAtLeast(0) }
    }

    companion object {
        const val PATH = "/v1/sessions/batch"
        private val JSON = "application/json".toMediaType()

        private fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}
