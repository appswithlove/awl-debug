package com.appswithlove.debug.api

/**
 * Controls what `DevHttpLogInterceptor` captures and which values it redacts before storing them.
 *
 * `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie` and userinfo in URLs are always
 * redacted, independent of this config.
 *
 * @param captureBodies Set to `false` to capture no request or response bodies at all.
 * @param maxBodyBytes Bodies are cut off after this many bytes, after redaction.
 * @param redactHeaders Additional header names whose values are redacted (case-insensitive).
 * @param redactJsonFields JSON and form fields whose values are redacted, at any depth. Matching
 * ignores case, `_` and `-`, so `accessToken` also matches `access_token`.
 * @param redactQueryParams Query parameters whose values are redacted (case-insensitive).
 * @param slowRequestThresholdMs Requests that take longer are labelled as slow.
 * @param streamContentTypes Additional response content types (`type/subtype`, case-insensitive)
 * that are treated as streams and never read. `text/event-stream` and `application/x-ndjson` are
 * always skipped.
 */
data class DevNetworkConfig(
    val captureBodies: Boolean = true,
    val maxBodyBytes: Int = 256 * 1024,
    val redactHeaders: Set<String> = emptySet(),
    val redactJsonFields: Set<String> = setOf("password", "accessToken", "refreshToken", "idToken", "clientSecret"),
    val redactQueryParams: Set<String> = setOf("access_token", "token", "api_key"),
    val slowRequestThresholdMs: Long = 1_000,
    val streamContentTypes: Set<String> = emptySet(),
)
