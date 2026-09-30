package com.appswithlove.debug.feedback.reporting

import android.content.Context

/** No-op stub: release builds never record or send anything. */
object AwlRemoteReporting {
    @Suppress("UNUSED_PARAMETER")
    fun start(context: Context, config: RemoteReportingConfig) = Unit

    @Suppress("UNUSED_PARAMETER")
    fun setUserIdentifier(appUserId: String?) = Unit

    fun flush() = Unit
}
