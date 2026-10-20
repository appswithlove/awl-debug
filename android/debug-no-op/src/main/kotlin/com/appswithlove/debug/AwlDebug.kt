package com.appswithlove.debug

import android.content.Intent

/** No-op stub: release builds never schedule debug deeplinks. */
object AwlDebug {
    @Suppress("UNUSED_PARAMETER")
    fun handleDeeplinkIntent(intent: Intent): Boolean = false
}
