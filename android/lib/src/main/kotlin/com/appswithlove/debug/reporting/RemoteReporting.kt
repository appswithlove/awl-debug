package com.appswithlove.debug.reporting

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.appswithlove.debug.api.AwlDistribution
import com.appswithlove.debug.api.reporting.RemoteReportingConfig
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import java.io.File
import java.util.concurrent.Executors

/** Process-wide entry point behind `AwlDebug.startRemoteReporting`. */
internal object RemoteReporting {
    private const val TAG = "AwlDebug"

    @Volatile
    var reporter: RemoteReporter? = null
        private set

    @Volatile
    private var appUserId: String? = null

    @Synchronized
    fun start(context: Context, config: RemoteReportingConfig) {
        if (reporter != null) return
        if (config.distribution == AwlDistribution.Store) {
            Log.w(TAG, "Remote reporting is off in store builds.")
            return
        }
        if (config.endpoint.isBlank() || config.appKey.isBlank()) {
            Log.w(TAG, "Remote reporting needs an endpoint and an app key.")
            return
        }
        val appContext = context.applicationContext
        val executor = Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "awl-debug-reporting").apply { isDaemon = true }
        }
        val buffer = ReportingBuffer(bufferDir(appContext))
        val created = RemoteReporter(appContext, config, buffer, executor, appUserId)
        reporter = created
        created.start()
        Handler(Looper.getMainLooper()).post {
            ProcessLifecycleOwner.get().lifecycle.addObserver(
                object : DefaultLifecycleObserver {
                    override fun onStart(owner: LifecycleOwner) {
                        created.onForeground()
                    }

                    override fun onStop(owner: LifecycleOwner) {
                        created.onBackground()
                    }
                },
            )
        }
    }

    fun onNetworkEntry(entry: NetworkEntry) {
        reporter?.onNetworkEntry(entry)
    }

    fun setUserIdentifier(appUserId: String?) {
        this.appUserId = appUserId
        reporter?.setUserIdentifier(appUserId)
    }

    fun flush() {
        reporter?.flush()
    }

    fun bufferDir(context: Context): File = File(context.filesDir, "awl-debug/reporting")
}
