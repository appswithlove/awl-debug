package com.appswithlove.debug.ui.dev.log

import okhttp3.Interceptor
import okhttp3.Response

/** No-op stub: production builds forward requests untouched, capturing no HTTP traffic. */
@Suppress("UNUSED_PARAMETER")
class DevHttpLogInterceptor @JvmOverloads constructor(
    logCollector: DevLogCollector = LogCollector.devLogCollector,
    redactHeaders: Set<String> = emptySet(),
    maxBodyBytes: Long = DEFAULT_MAX_BODY_BYTES,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response =
        chain.proceed(chain.request())

    companion object {
        const val DEFAULT_MAX_BODY_BYTES: Long = 256L * 1024
    }
}
