package com.appswithlove.debug.domain.model

import android.content.Context
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf

/** No-op stub: the dev tool is never active in production builds. */
@Suppress("UNUSED_PARAMETER")
object DevSettings {
    suspend fun activateDevTool(context: Context, activate: Boolean) {}
    fun isDevToolActivated(context: Context): Flow<Boolean> = flowOf(false)
}
