package com.appswithlove.debug.ui.dev.network

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.domain.storage.NetworkPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

internal data class NetworkUiState(
    /** Entries after search, filters and sorting. */
    val entries: List<NetworkEntry> = emptyList(),
    val maxSize: Int = NetworkLogStore.DEFAULT_MAX_SIZE,
    val isTracking: Boolean = true,
    val filter: NetworkFilter = NetworkFilter(),
    val sort: NetworkSort = NetworkSort.NewestFirst,
    /** Filter values seen in the captured traffic, plus values currently hidden. */
    val methods: List<String> = emptyList(),
    val hosts: List<String> = emptyList(),
)

internal class NetworkViewModel(
    private val store: NetworkLogStore,
    private val devStore: DevStore,
) : ViewModel() {

    private val query = MutableStateFlow("")
    private val preferences = MutableStateFlow(NetworkPreferences())

    val state: StateFlow<NetworkUiState> = combine(
        store.entries,
        store.maxSize,
        store.isTracking,
        preferences,
        query,
    ) { entries, maxSize, isTracking, preferences, query ->
        val filter = NetworkFilter(
            query = query,
            excludedMethods = preferences.excludedMethods,
            excludedStatusClasses = preferences.excludedStatusClasses.mapNotNullTo(mutableSetOf()) { name ->
                StatusClass.entries.find { it.name == name }
            },
            excludedHosts = preferences.excludedHosts,
        )
        val sort = NetworkSort.entries.find { it.name == preferences.sort } ?: NetworkSort.NewestFirst
        NetworkUiState(
            entries = entries.filteredAndSorted(filter, sort),
            maxSize = maxSize,
            isTracking = isTracking,
            filter = filter,
            sort = sort,
            methods = (entries.map { it.method } + preferences.excludedMethods).distinct().sorted(),
            hosts = (entries.map { it.host } + preferences.excludedHosts).distinct().sorted(),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), NetworkUiState())

    init {
        viewModelScope.launch {
            val saved = devStore.networkPreferences.first()
            preferences.value = saved
            store.setTracking(saved.isTracking)
            saved.maxSize?.let(store::setMaxSize)
        }
    }

    fun entry(id: Long): NetworkEntry? = store.entries.value.find { it.id == id }

    fun search(value: String) {
        query.value = value
    }

    fun setExcludedMethods(methods: Set<String>) = updatePreferences { it.copy(excludedMethods = methods) }

    fun setExcludedStatusClasses(classes: Set<StatusClass>) =
        updatePreferences { it.copy(excludedStatusClasses = classes.mapTo(mutableSetOf()) { status -> status.name }) }

    fun setExcludedHosts(hosts: Set<String>) = updatePreferences { it.copy(excludedHosts = hosts) }

    fun setSort(sort: NetworkSort) = updatePreferences { it.copy(sort = sort.name) }

    fun setTracking(track: Boolean) {
        store.setTracking(track)
        updatePreferences { it.copy(isTracking = track) }
    }

    fun setMaxSize(size: Int) {
        store.setMaxSize(size)
        updatePreferences { it.copy(maxSize = size) }
    }

    fun clear() = store.clear()

    private fun updatePreferences(change: (NetworkPreferences) -> NetworkPreferences) {
        preferences.update(change)
        val updated = preferences.value
        viewModelScope.launch { devStore.setNetworkPreferences(updated) }
    }
}
