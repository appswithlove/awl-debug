@file:OptIn(AwlDebugInternalApi::class)

package com.appswithlove.debug.api.extension

import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Lets other libraries add rows to the debug panel and read what the panel captured.
 *
 * Sections added with [register] appear on the panel's start page, directly below App Info. The data functions
 * return what the panel holds: already redacted, the newest entries, oldest first.
 *
 * Part of `debug-api`, so the same calls compile against `debug` and `debug-no-op`. With `debug-no-op` nothing is
 * shown or captured: listeners are never called, snapshots are empty or `null` and there is no recording.
 */
object AwlDebugExtensions {
    private val registered = MutableStateFlow<List<DevExtensionSection>>(emptyList())
    private val networkListeners = CopyOnWriteArrayList<NetworkListener>()
    private val listenerThread: ExecutorService by lazy {
        Executors.newSingleThreadExecutor { runnable -> Thread(runnable, "awl-debug-extensions").apply { isDaemon = true } }
    }

    @Volatile
    private var provider: DevExtensionProvider? = null

    /** Registered sections, sorted by [DevExtensionSection.order], then by registration. The panel shows these. */
    val sections: StateFlow<List<DevExtensionSection>> = registered.asStateFlow()

    /**
     * Adds [section] to the panel until the returned handle is closed. A section with the [DevExtensionSection.id]
     * of a registered one replaces it.
     */
    fun register(section: DevExtensionSection): AutoCloseable {
        registered.update { current -> (current.filterNot { it.id == section.id } + section).sortedBy { it.order } }
        return closeOnce { registered.update { current -> current.filterNot { it === section } } }
    }

    /**
     * Calls [listener] with every request that `DevHttpLogInterceptor` finishes from now on, until the returned
     * handle is closed. Works before any interceptor exists. Called on a background thread, one record at a time.
     */
    fun addNetworkListener(listener: (DevNetworkRecord) -> Unit): AutoCloseable {
        val registration = NetworkListener(listener)
        networkListeners += registration
        return closeOnce { networkListeners.remove(registration) }
    }

    /**
     * `true` once the `debug` artifact is in use, that is after the first `DevSheet`, `DevHttpLogInterceptor` or
     * logged entry. Always `false` with `debug-no-op`.
     */
    val isDebugArtifactPresent: Boolean
        get() = provider != null

    /**
     * The newest [maxEntries] log entries that match the Logs module's search and severity filter, with that filter.
     * `null` while [isDebugArtifactPresent] is `false`.
     */
    suspend fun logSnapshot(maxEntries: Int): DevLogSnapshot? = provider?.logSnapshot(maxEntries.coerceAtLeast(0))

    /** The newest [maxEntries] captured requests, oldest first, without the Network module's filters. */
    fun networkSnapshot(maxEntries: Int): List<DevNetworkRecord> =
        provider?.networkSnapshot(maxEntries.coerceAtLeast(0)).orEmpty()

    /** `true` while frames of a screen recording of this or the previous app run exist. */
    fun hasRecording(): Boolean = provider?.hasRecording() == true

    /**
     * Writes the screen recording of this run, or of the previous run when this one has none, as files within
     * [options]. Returns `null` without frames. Runs off the main thread and can take several seconds.
     */
    suspend fun exportRecording(options: DevRecordingExportOptions): DevRecordingExport? = provider?.exportRecording(options)

    /** Connects the `debug` artifact. Not for app code. */
    @AwlDebugInternalApi
    fun installProvider(provider: DevExtensionProvider) {
        this.provider = provider
    }

    /** Hands a finished request to the listeners. Not for app code. */
    @AwlDebugInternalApi
    fun publishNetworkRecord(record: DevNetworkRecord) {
        if (networkListeners.isEmpty()) return
        listenerThread.execute {
            networkListeners.forEach { registration ->
                try {
                    registration.listener(record)
                } catch (e: Exception) {
                    // One failing listener must neither stop the others nor the app's request.
                    e.printStackTrace()
                }
            }
        }
    }

    /** Wrapper, so the same lambda can be added twice and removed once. */
    private class NetworkListener(val listener: (DevNetworkRecord) -> Unit)

    private fun closeOnce(onClose: () -> Unit): AutoCloseable {
        val closed = AtomicBoolean(false)
        return AutoCloseable { if (closed.compareAndSet(false, true)) onClose() }
    }
}

/** What the `debug` artifact provides to [AwlDebugExtensions]. Not for app code. */
@AwlDebugInternalApi
interface DevExtensionProvider {
    suspend fun logSnapshot(maxEntries: Int): DevLogSnapshot

    fun networkSnapshot(maxEntries: Int): List<DevNetworkRecord>

    fun hasRecording(): Boolean

    suspend fun exportRecording(options: DevRecordingExportOptions): DevRecordingExport?
}
