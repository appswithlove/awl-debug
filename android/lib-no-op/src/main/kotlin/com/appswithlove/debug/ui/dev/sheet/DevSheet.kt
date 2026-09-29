package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.DevModulesConfig
import com.appswithlove.debug.api.DevTrigger

/**
 * No-op stub of `DevSheet` for production flavors. Renders [content] only — no
 * gestures, no sensors, no debug UI, no log collection. Has the same public
 * signature as the real `DevSheet`, so the same source compiles against either artifact.
 */
@Composable
@Suppress("UNUSED_PARAMETER")
fun DevSheet(
    modifier: Modifier = Modifier,
    devConfig: DevConfig? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    triggers: Set<DevTrigger> = setOf(DevTrigger.ThreeFingerTap),
    customModules: @Composable ColumnScope.() -> Unit = {},
    isAlwaysActive: Boolean = false,
    swipeToDismiss: Boolean = false,
    inheritHostTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    content()
}
