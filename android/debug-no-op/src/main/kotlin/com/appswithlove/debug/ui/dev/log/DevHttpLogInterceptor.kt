package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import okhttp3.Interceptor
import okhttp3.Response

/** No-op stub: production builds forward requests untouched, capturing no HTTP traffic. */
@Suppress("UNUSED_PARAMETER")
class DevHttpLogInterceptor(
    config: DevNetworkConfig = DevNetworkConfig(),
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response =
        chain.proceed(chain.request())
}
