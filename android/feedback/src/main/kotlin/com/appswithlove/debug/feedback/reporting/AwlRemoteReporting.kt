package com.appswithlove.debug.feedback.reporting

import android.content.Context
import com.appswithlove.debug.feedback.AwlDistribution

/**
 * Sends sessions, requests captured by `DevHttpLogInterceptor` and performance samples of test builds to the
 * feedback service. The debug panel shows its state below App Info.
 */
object AwlRemoteReporting {
    /**
     * Starts reporting. Call once from `Application.onCreate`; later calls are ignored.
     * Does nothing when [RemoteReportingConfig.distribution] is [AwlDistribution.Store].
     */
    fun start(context: Context, config: RemoteReportingConfig) {
        RemoteReporting.start(context, config)
    }

    /**
     * Links the following sessions to a user of the app, for example after login; `null` after logout.
     * Only a SHA-256 hash of the app key and [appUserId] leaves the device.
     */
    fun setUserIdentifier(appUserId: String?) {
        RemoteReporting.setUserIdentifier(appUserId)
    }

    /** Packs everything recorded so far into batches and sends them. */
    fun flush() {
        RemoteReporting.flush()
    }
}
