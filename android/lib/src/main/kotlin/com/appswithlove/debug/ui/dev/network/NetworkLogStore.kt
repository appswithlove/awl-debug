package com.appswithlove.debug.ui.dev.network

import com.appswithlove.debug.bridge.LogsAttachment
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.concurrent.atomic.AtomicLong

/** In-memory ring buffer of captured requests, oldest first. */
internal class NetworkLogStore(maxSize: Int = DEFAULT_MAX_SIZE) {
    private val nextId = AtomicLong()

    private val _entries = MutableStateFlow<List<NetworkEntry>>(emptyList())
    val entries: StateFlow<List<NetworkEntry>> = _entries.asStateFlow()

    private val _maxSize = MutableStateFlow(maxSize)
    val maxSize: StateFlow<Int> = _maxSize.asStateFlow()

    private val _isTracking = MutableStateFlow(true)
    val isTracking: StateFlow<Boolean> = _isTracking.asStateFlow()

    /** `true` once any interceptor has been created, which makes the module visible. */
    private val _hasInterceptor = MutableStateFlow(false)
    val hasInterceptor: StateFlow<Boolean> = _hasInterceptor.asStateFlow()

    fun newId(): Long = nextId.incrementAndGet()

    fun add(entry: NetworkEntry) {
        if (!_isTracking.value) return
        _entries.update { (it + entry).takeLast(_maxSize.value) }
    }

    fun clear() {
        _entries.value = emptyList()
    }

    fun setMaxSize(size: Int) {
        _maxSize.value = size
        _entries.update { it.takeLast(size) }
    }

    fun setTracking(track: Boolean) {
        _isTracking.value = track
    }

    fun onInterceptorCreated() {
        _hasInterceptor.value = true
    }

    companion object {
        const val DEFAULT_MAX_SIZE = 750
    }
}

internal object NetworkCollector {
    val store = NetworkLogStore()

    init {
        LogsAttachment.register()
    }
}
