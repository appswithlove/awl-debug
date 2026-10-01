package com.appswithlove.debug

import android.content.Context
import android.content.Intent
import com.appswithlove.debug.api.reporting.RemoteReportingConfig

/** No-op stub: release builds never schedule debug deeplinks and never report anything. */
object AwlDebug {
    @Suppress("UNUSED_PARAMETER")
    fun handleDeeplinkIntent(intent: Intent): Boolean = false

    @Suppress("UNUSED_PARAMETER")
    fun startRemoteReporting(context: Context, config: RemoteReportingConfig) = Unit

    @Suppress("UNUSED_PARAMETER")
    fun setUserIdentifier(appUserId: String?) = Unit

    fun flushReports() = Unit
}
