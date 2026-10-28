package com.appswithlove.debug.ui.dev.network

/** One captured HTTP exchange. All values are already redacted. */
internal data class NetworkEntry(
    val id: Long,
    val startedAtMillis: Long,
    val method: String,
    val url: String,
    val host: String,
    val path: String,
    /** HTTP status code, `0` when the request failed without a response. */
    val status: Int,
    val reason: String?,
    val durationMs: Long,
    val requestBytes: Long?,
    val responseBytes: Long?,
    val requestHeaders: List<Pair<String, String>>,
    val responseHeaders: List<Pair<String, String>>,
    /** `null` when the request or response has no body. */
    val requestBody: CapturedBody?,
    val responseBody: CapturedBody?,
    val error: String?,
    val redactedCount: Int,
    val isSlow: Boolean,
    /** Why the request failed (`timeout`, `dns`, `tls`, `cancelled`, `connection`); `null` with a response. */
    val errorCode: String? = error?.let(::networkErrorCode),
) {
    val isFailed: Boolean get() = status == 0
}

internal data class CapturedBody(
    /** Body text, or a placeholder such as `(binary, 12 bytes)` when the content is not stored. */
    val text: String,
    val contentType: String?,
    val truncated: Boolean = false,
    /** Size before truncation, `null` when unknown. */
    val originalBytes: Long? = null,
    /** `false` when [text] is a placeholder instead of the body content. */
    val isContent: Boolean = true,
)

/**
 * Short error code for a failed request: `timeout`, `dns`, `tls`, `cancelled` or `connection`.
 * [error] is the `toString()` of the exception, so it starts with the class name.
 */
internal fun networkErrorCode(error: String?): String {
    val type = error?.substringBefore(':')?.trim().orEmpty()
    val message = error?.substringAfter(':', "")?.trim().orEmpty()
    return when {
        type.endsWith("SocketTimeoutException") || type.endsWith("InterruptedIOException") && message == "timeout" -> "timeout"
        type.endsWith("UnknownHostException") -> "dns"
        type.startsWith("javax.net.ssl.") || type.contains("SSL") -> "tls"
        message.equals("Canceled", ignoreCase = true) -> "cancelled"
        else -> "connection"
    }
}
