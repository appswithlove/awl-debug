package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.runtime.Stable

@Stable
data class DevSheetState(
    val isActive: Boolean = false,
    val isAlwaysActive: Boolean = false,
    val isShown: Boolean = false,
    //settings what to show
) {
    companion object {
        val Preview = DevSheetState(
            isActive = true,
            isShown = true,
        )
    }
}
