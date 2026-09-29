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
