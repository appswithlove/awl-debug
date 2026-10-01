package com.appswithlove.debug

import android.content.Context
import android.content.Intent
import com.appswithlove.debug.api.reporting.RemoteReportingConfig
import com.appswithlove.debug.reporting.RemoteReporting
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DEEPLINK_EXTRA
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinkDispatcher

object AwlDebug {
    /**
     * Call from the launcher activity's `onCreate` and `onNewIntent` when the app sets
     * `DevModulesConfig.deeplinkHandler`: a tapped delayed-deeplink notification then reaches that handler.
     *
     * @return `true` when [intent] came from such a notification.
     */
    fun handleDeeplinkIntent(intent: Intent): Boolean {
        val url = intent.getStringExtra(DEEPLINK_EXTRA) ?: return false
        intent.removeExtra(DEEPLINK_EXTRA)
        DeeplinkDispatcher.deliverToHandler(url)
        return true
    }

    /**
     * Starts recording sessions, requests captured by `DevHttpLogInterceptor` and performance samples
     * for the feedback service. Call once from `Application.onCreate`; later calls are ignored.
     * Does nothing when [RemoteReportingConfig.distribution] is `Store`.
     */
    fun startRemoteReporting(context: Context, config: RemoteReportingConfig) {
        RemoteReporting.start(context, config)
    }

    /**
     * Links the following sessions to a user of the app, for example after login; `null` after logout.
     * Only a SHA-256 hash of the app key and [appUserId] leaves the device.
     */
    fun setUserIdentifier(appUserId: String?) {
        RemoteReporting.setUserIdentifier(appUserId)
    }

    /** Packs everything recorded so far into batches for sending. */
    fun flushReports() {
        RemoteReporting.flush()
    }
}
