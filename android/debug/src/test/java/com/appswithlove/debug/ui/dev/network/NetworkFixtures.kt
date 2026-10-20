package com.appswithlove.debug.ui.dev.network

/** 2026-09-29T10:15:30.123Z */
internal const val FIXTURE_TIME = 1_790_676_930_123L

internal fun networkEntry(
    id: Long = 1,
    method: String = "GET",
    url: String = "https://api.example.com/v1/items?page=2",
    status: Int = 200,
    durationMs: Long = 120,
    requestHeaders: List<Pair<String, String>> = emptyList(),
    requestBody: CapturedBody? = null,
    responseHeaders: List<Pair<String, String>> = listOf("Content-Type" to "application/json"),
    responseBody: CapturedBody? = CapturedBody("""{"items":[{"id":1,"name":"Test"}]}""", "application/json"),
    error: String? = null,
    redactedCount: Int = 0,
): NetworkEntry {
    val host = url.substringAfter("://").substringBefore('/').substringAfter('@')
    return NetworkEntry(
        id = id,
        startedAtMillis = FIXTURE_TIME + id * 1_000,
        method = method,
        url = url,
        host = host,
        path = "/" + url.substringAfter("://").substringAfter('/', "").substringBefore('?'),
        status = status,
        reason = if (status == 0) null else "OK",
        durationMs = durationMs,
        requestBytes = requestBody?.originalBytes,
        responseBytes = responseBody?.originalBytes,
        requestHeaders = requestHeaders,
        responseHeaders = responseHeaders,
        requestBody = requestBody,
        responseBody = responseBody,
        error = error,
        redactedCount = redactedCount,
        isSlow = durationMs > 1_000,
    )
}
