package com.appswithlove.debug.ui.dev.recording

import android.view.View
import androidx.compose.ui.Modifier

/** No-op: release builds never record the screen. */
fun Modifier.awlDebugMasked(): Modifier = this

/** No-op: release builds never record the screen, so the value is never stored. */
var View.awlDebugMasked: Boolean
    get() = false
    @Suppress("UNUSED_PARAMETER")
    set(value) = Unit
