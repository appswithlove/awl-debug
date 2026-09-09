package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.DevModulesConfig

/**
 * No-op stub of `DevSheet` for production flavors. Renders [content] only — no
 * three-finger-tap gesture, no debug UI, no log collection. Mirrors the public
 * call sites of the real `DevSheet` so the same source compiles against either
 * artifact; the internal-only `viewModel` and `logHistory` overrides are omitted.
 */
@Composable
@Suppress("UNUSED_PARAMETER")
fun DevSheet(
    modifier: Modifier = Modifier,
    devConfig: DevConfig? = null,
    modulesConfig: DevModulesConfig = DevModulesConfig(),
    customModules: @Composable ColumnScope.() -> Unit = {},
    isAlwaysActive: Boolean = false,
    swipeToDismiss: Boolean = false,
    inheritHostTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    content()
}
