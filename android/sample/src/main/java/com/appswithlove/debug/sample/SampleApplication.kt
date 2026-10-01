package com.appswithlove.debug.sample

import android.app.Application
import com.appswithlove.debug.feedback.AwlDistribution
import com.appswithlove.debug.feedback.reporting.AwlRemoteReporting
import com.appswithlove.debug.feedback.reporting.RemoteReportingConfig

class SampleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Same local.properties values as feedback; without them nothing is recorded.
        if (BuildConfig.FEEDBACK_ENDPOINT.isNotEmpty()) {
            AwlRemoteReporting.start(
                this,
                RemoteReportingConfig(
                    endpoint = BuildConfig.FEEDBACK_ENDPOINT,
                    appKey = BuildConfig.FEEDBACK_APP_KEY,
                    environment = "local",
                    distribution = AwlDistribution.Debug,
                ),
            )
            AwlRemoteReporting.setUserIdentifier("42") // only a hash of it is sent
        }
    }
}
