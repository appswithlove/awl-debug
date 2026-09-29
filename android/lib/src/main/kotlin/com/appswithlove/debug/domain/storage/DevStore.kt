package com.appswithlove.debug.domain.storage

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.appswithlove.debug.api.DeeplinkItem
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.coroutines.flow.map

//needs to be outside of the class!!
private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "dev_settings")

internal class DevStore(context: Context) {
    private val dataStore: DataStore<Preferences> = context.dataStore

    companion object {
        @Volatile
        private var instance: DevStore? = null

        fun getInstance(context: Context): DevStore =
            instance ?: synchronized(this) {
                instance ?: DevStore(context).also { instance = it }
            }

        private val DEV_TOOL_ACTIVATED_KEY = booleanPreferencesKey("DEV_TOOL_ACTIVATED_KEY")

        private val DEV_TOOL_ALWAYS_ACTIVE_KEY = booleanPreferencesKey("ACTIVATE_DEV_TOOL_KEY")

        private val NETWORK_TRACKING_KEY = booleanPreferencesKey("NETWORK_TRACKING_KEY")
        private val NETWORK_MAX_SIZE_KEY = intPreferencesKey("NETWORK_MAX_SIZE_KEY")
        private val NETWORK_SORT_KEY = stringPreferencesKey("NETWORK_SORT_KEY")
        private val NETWORK_EXCLUDED_METHODS_KEY = stringSetPreferencesKey("NETWORK_EXCLUDED_METHODS_KEY")
        private val NETWORK_EXCLUDED_STATUS_KEY = stringSetPreferencesKey("NETWORK_EXCLUDED_STATUS_KEY")
        private val NETWORK_EXCLUDED_HOSTS_KEY = stringSetPreferencesKey("NETWORK_EXCLUDED_HOSTS_KEY")

        private val SAVED_DEEPLINKS_KEY = stringPreferencesKey("SAVED_DEEPLINKS_KEY")
    }

    /** Deeplinks testers saved on this device, in the order they were added. */
    val savedDeeplinks: Flow<List<DeeplinkItem>> = dataStore.data
        .map { preferences -> decodeDeeplinks(preferences[SAVED_DEEPLINKS_KEY]) }

    suspend fun setSavedDeeplinks(deeplinks: List<DeeplinkItem>) {
        dataStore.edit { preferences -> preferences[SAVED_DEEPLINKS_KEY] = encodeDeeplinks(deeplinks) }
    }

    private fun encodeDeeplinks(deeplinks: List<DeeplinkItem>): String = JsonArray(
        deeplinks.map { JsonObject(mapOf("label" to JsonPrimitive(it.label), "url" to JsonPrimitive(it.url))) }
    ).toString()

    private fun decodeDeeplinks(json: String?): List<DeeplinkItem> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            Json.parseToJsonElement(json).jsonArray.mapNotNull { element ->
                val item = element.jsonObject
                val url = item["url"]?.jsonPrimitive?.content ?: return@mapNotNull null
                DeeplinkItem(label = item["label"]?.jsonPrimitive?.content ?: url, url = url)
            }
        } catch (_: IllegalArgumentException) {
            emptyList()
        }
    }

    val networkPreferences: Flow<NetworkPreferences> = dataStore.data
        .map { preferences ->
            NetworkPreferences(
                isTracking = preferences[NETWORK_TRACKING_KEY] ?: true,
                maxSize = preferences[NETWORK_MAX_SIZE_KEY],
                sort = preferences[NETWORK_SORT_KEY],
                excludedMethods = preferences[NETWORK_EXCLUDED_METHODS_KEY].orEmpty(),
                excludedStatusClasses = preferences[NETWORK_EXCLUDED_STATUS_KEY].orEmpty(),
                excludedHosts = preferences[NETWORK_EXCLUDED_HOSTS_KEY].orEmpty(),
            )
        }

    suspend fun setNetworkPreferences(value: NetworkPreferences) {
        dataStore.edit { preferences ->
            preferences[NETWORK_TRACKING_KEY] = value.isTracking
            value.maxSize?.let { preferences[NETWORK_MAX_SIZE_KEY] = it }
            value.sort?.let { preferences[NETWORK_SORT_KEY] = it }
            preferences[NETWORK_EXCLUDED_METHODS_KEY] = value.excludedMethods
            preferences[NETWORK_EXCLUDED_STATUS_KEY] = value.excludedStatusClasses
            preferences[NETWORK_EXCLUDED_HOSTS_KEY] = value.excludedHosts
        }
    }

    val isDevToolActivated: Flow<Boolean> = dataStore.data
        .map { preferences ->
            preferences[DEV_TOOL_ACTIVATED_KEY] ?: false
        }

    suspend fun setDevToolActivated(value: Boolean) {
        dataStore.edit { preferences ->
            preferences[DEV_TOOL_ACTIVATED_KEY] = value
        }
    }

    val isDevToolAlwaysActive: Flow<Boolean> = dataStore.data
        .map { preferences ->
            preferences[DEV_TOOL_ALWAYS_ACTIVE_KEY] ?: false
        }

    suspend fun setDevToolAlwaysActive(value: Boolean) {
        dataStore.edit { preferences ->
            preferences[DEV_TOOL_ALWAYS_ACTIVE_KEY] = value
        }
    }

    suspend fun activateDevTool(activate: Boolean) {
        try {
            setDevToolActivated(activate)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

/** Network module settings persisted per device. Enum values are stored by name. */
internal data class NetworkPreferences(
    val isTracking: Boolean = true,
    val maxSize: Int? = null,
    val sort: String? = null,
    val excludedMethods: Set<String> = emptySet(),
    val excludedStatusClasses: Set<String> = emptySet(),
    val excludedHosts: Set<String> = emptySet(),
)
