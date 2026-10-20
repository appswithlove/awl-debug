package com.appswithlove.debug.domain.model

import android.content.Context
import com.appswithlove.debug.domain.storage.DevStore
import kotlinx.coroutines.flow.Flow

object DevSettings {

    suspend fun activateDevTool(context: Context, activate: Boolean) {
        DevStore.getInstance(context).activateDevTool(activate)
    }

    @Suppress("Unused")
    fun isDevToolActivated(context: Context): Flow<Boolean> {
        return DevStore.getInstance(context).isDevToolActivated
    }
}
