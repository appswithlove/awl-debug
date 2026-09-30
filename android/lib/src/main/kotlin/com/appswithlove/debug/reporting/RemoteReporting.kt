package com.appswithlove.debug.reporting

import android.content.Context
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.Network
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.appswithlove.debug.api.AwlDistribution
import com.appswithlove.debug.api.reporting.RemoteReportingConfig
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Process-wide entry point behind `AwlDebug.startRemoteReporting`. */
internal object RemoteReporting {
    private const val TAG = "AwlDebug"
    private const val PREFS = "awl_debug_reporting"
    private const val KEY_SEND = "send_session_data"
    const val FLUSH_INTERVAL_MS = 30_000L

    private val mutableStatus = MutableStateFlow(ReportingStatus())

    /** The panel shows a row once [ReportingStatus.isConfigured]. */
    val status: StateFlow<ReportingStatus> = mutableStatus.asStateFlow()

    @Volatile
    private var uploader: ReportingUploader? = null

    @Volatile
    private var preferences: SharedPreferences? = null

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
            mutableStatus.value = ReportingStatus(isConfigured = true, isStoreBuild = true, isSendingEnabled = false)
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
        val prefs = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        preferences = prefs
        val sendingEnabled = prefs.getBoolean(KEY_SEND, true)
        val status = mutableStatus.apply { value = ReportingStatus(isConfigured = true, isSendingEnabled = sendingEnabled) }
        val buffer = ReportingBuffer(bufferDir(appContext))
        val connectivity = appContext.getSystemService(ConnectivityManager::class.java)
        val created = RemoteReporter(appContext, config, buffer, executor, appUserId, status = status)
        val createdUploader = ReportingUploader(
            bufferExecutor = executor,
            buffer = buffer,
            sender = ReportingSender(config.endpoint, config.appKey),
            status = status,
            canSend = { !config.onlyOnUnmeteredNetwork || connectivity?.isUnmetered() == true },
            onStopped = { created.setRecording(false) },
        )
        created.setRecording(sendingEnabled)
        // Queued before any request can reach the reporter, so leftovers are sealed before new entries.
        created.start()
        reporter = created
        uploader = createdUploader
        createdUploader.upload(ignoreBackoff = true)
        executor.scheduleWithFixedDelay(
            { if (status.value.isOn) flush(ignoreBackoff = false) },
            FLUSH_INTERVAL_MS,
            FLUSH_INTERVAL_MS,
            TimeUnit.MILLISECONDS,
        )
        try {
            connectivity?.registerDefaultNetworkCallback(
                object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        createdUploader.upload(ignoreBackoff = true)
                    }
                },
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "Remote reporting cannot watch the network: ${e.message}")
        }
        Handler(Looper.getMainLooper()).post {
            ProcessLifecycleOwner.get().lifecycle.addObserver(
                object : DefaultLifecycleObserver {
                    override fun onStart(owner: LifecycleOwner) {
                        created.onForeground()
                    }

                    override fun onStop(owner: LifecycleOwner) {
                        created.onBackground()
                        createdUploader.upload(ignoreBackoff = true)
                    }
                },
            )
        }
    }

    fun onNetworkEntry(entry: NetworkEntry) {
        reporter?.onNetworkEntry(entry)
    }

    @Synchronized
    fun setUserIdentifier(appUserId: String?) {
        this.appUserId = appUserId
        reporter?.setUserIdentifier(appUserId)
    }

    /** "Flush now" and `AwlDebug.flushReports`: seals what is recorded and sends it, ignoring the backoff. */
    fun flush() {
        flush(ignoreBackoff = true)
    }

    private fun flush(ignoreBackoff: Boolean) {
        val reporter = reporter ?: return
        reporter.flush()
        uploader?.upload(ignoreBackoff)
    }

    /** "Send session data": stored per device, on by default. */
    fun setSendingEnabled(enabled: Boolean) {
        val reporter = reporter ?: return
        preferences?.edit()?.putBoolean(KEY_SEND, enabled)?.apply()
        mutableStatus.update { it.copy(isSendingEnabled = enabled) }
        reporter.setRecording(enabled && mutableStatus.value.stoppedStatus == null)
        if (enabled) uploader?.upload(ignoreBackoff = true)
    }

    private fun ConnectivityManager.isUnmetered(): Boolean = activeNetwork != null && !isActiveNetworkMetered

    fun bufferDir(context: Context): File = File(context.filesDir, "awl-debug/reporting")
}
