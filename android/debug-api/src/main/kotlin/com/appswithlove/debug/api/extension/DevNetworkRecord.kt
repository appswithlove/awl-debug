package com.appswithlove.debug.api.extension

/**
 * One finished HTTP request as `DevHttpLogInterceptor` captured it, redacted like in the Network module.
 *
 * @param startedAtMillis When the request started, in milliseconds since the epoch.
 * @param method HTTP method, for example `GET`.
 * @param url Redacted URL.
 * @param status HTTP status code; `null` when the request failed without a response.
 * @param durationMs Time until the response headers arrived or the request failed.
 * @param requestHeaders Redacted request headers in the order they were sent.
 * @param responseHeaders Redacted response headers; empty without a response.
 * @param requestBody Captured request body; `null` without one.
 * @param responseBody Captured response body; `null` without one.
 * @param errorCode Why the request failed: `timeout`, `dns`, `tls`, `cancelled` or `connection`; `null` with a response.
 * @param requestBytes Size of the request body; `null` when unknown.
 * @param responseBytes Size of the response body; `null` when unknown.
 */
class DevNetworkRecord(
    val startedAtMillis: Long,
    val method: String,
    val url: String,
    val status: Int?,
    val durationMs: Long,
    val requestHeaders: List<Pair<String, String>>,
    val responseHeaders: List<Pair<String, String>>,
    val requestBody: DevNetworkBody?,
    val responseBody: DevNetworkBody?,
    val errorCode: String?,
    val requestBytes: Long?,
    val responseBytes: Long?,
)

/**
 * A captured request or response body.
 *
 * @param text Redacted body text, or a placeholder such as `(binary, 12 bytes)` when [isContent] is `false`.
 * @param contentType Content type; `null` when unknown.
 * @param truncated `true` when [text] was cut off.
 * @param originalBytes Size before cutting off; `null` when unknown.
 * @param isContent `false` when [text] is a placeholder instead of the body.
 */
class DevNetworkBody(
    val text: String,
    val contentType: String?,
    val truncated: Boolean,
    val originalBytes: Long?,
    val isContent: Boolean,
)
