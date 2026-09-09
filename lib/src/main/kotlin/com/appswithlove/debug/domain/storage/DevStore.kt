package com.appswithlove.debug.domain.storage

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

//needs to be outside of the class!!
private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "dev_settings")

class DevStore(context: Context) {
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
