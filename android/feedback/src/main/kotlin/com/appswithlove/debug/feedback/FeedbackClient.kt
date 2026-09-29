package com.appswithlove.debug.feedback

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

internal class EncodedImage(val bytes: ByteArray, val mimeType: String, val fileName: String)

internal sealed interface SendError {
    data object Unauthorized : SendError
    data object TooLarge : SendError
    data object UnsupportedMedia : SendError
    data class RateLimited(val retryAfterSeconds: Int?) : SendError
    data object Invalid : SendError
    data object Server : SendError
    data object Network : SendError
    data object InvalidEndpoint : SendError
    data object Unknown : SendError
}

internal sealed interface SendResult {
    data class Success(val taskId: String?) : SendResult
    data class Failure(val error: SendError) : SendResult
}

internal fun errorForStatus(code: Int, retryAfter: String?): SendError = when (code) {
    400 -> SendError.Invalid
    401, 403 -> SendError.Unauthorized
    413 -> SendError.TooLarge
    415 -> SendError.UnsupportedMedia
    429 -> SendError.RateLimited(retryAfter?.trim()?.toIntOrNull())
    in 500..599 -> SendError.Server
    else -> SendError.Unknown
}

internal class FeedbackClient(
    private val httpClient: OkHttpClient = defaultHttpClient,
) {
    suspend fun send(
        config: FeedbackConfig,
        text: String,
        metadataJson: String,
        screenshot: EncodedImage,
    ): SendResult = withContext(Dispatchers.IO) {
        val body = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("text", text)
            .addFormDataPart("metadata", metadataJson)
            .addFormDataPart("screenshot", screenshot.fileName, screenshot.bytes.toRequestBody(screenshot.mimeType.toMediaType()))
            .build()
        val request = try {
            Request.Builder()
                .url("${config.endpoint.trimEnd('/')}/v1/feedback")
                .header("X-App-Key", config.appKey)
                .post(body)
                .build()
        } catch (_: IllegalArgumentException) {
            return@withContext SendResult.Failure(SendError.InvalidEndpoint)
        }
        try {
            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    SendResult.Success(taskId = response.body?.string()?.taskIdOrNull())
                } else {
                    SendResult.Failure(errorForStatus(response.code, response.header("Retry-After")))
                }
            }
        } catch (_: IOException) {
            SendResult.Failure(SendError.Network)
        }
    }

    private fun String.taskIdOrNull(): String? = try {
        JSONObject(this).optString("taskId").takeIf { it.isNotEmpty() }
    } catch (_: org.json.JSONException) {
        null
    }

    private companion object {
        val defaultHttpClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .callTimeout(30, TimeUnit.SECONDS)
                .build()
        }
    }
}
