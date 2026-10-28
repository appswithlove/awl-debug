package com.appswithlove.debug.ui.dev.sheet.modules.accessibility

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

internal enum class Appearance(val label: String) {
    System("System"),
    Light("Light"),
    Dark("Dark"),
}

/** Font size and appearance overrides for the app content inside `DevSheet`, stored per device. */
internal data class AccessibilitySettings(
    val useSystemFontScale: Boolean = true,
    val fontScale: Float = 1f,
    val appearance: Appearance = Appearance.System,
) {
    val isOverriding: Boolean get() = !useSystemFontScale || appearance != Appearance.System
}

/** Font size steps shared with iOS; larger accessibility sizes do not exist on Android. */
internal val FONT_SCALE_PRESETS = listOf(
    "Extra Small" to 0.80f,
    "Small" to 0.85f,
    "Medium" to 0.90f,
    "Large" to 1.00f,
    "Extra Large" to 1.15f,
    "XX Large" to 1.30f,
    "XXX Large" to 1.50f,
    "Accessibility M" to 1.80f,
    "Accessibility L" to 2.00f,
)

/** Applies [settings] to [content]: font scale through [LocalDensity], appearance through the configuration's `uiMode`. */
@Composable
internal fun AccessibilityOverride(settings: AccessibilitySettings, content: @Composable () -> Unit) {
    val density = LocalDensity.current
    val configuration = LocalConfiguration.current
    val overriddenDensity = if (settings.useSystemFontScale) density else Density(density.density, settings.fontScale)
    val overriddenConfiguration = remember(configuration, settings.appearance) {
        val nightMode = when (settings.appearance) {
            Appearance.System -> null
            Appearance.Light -> Configuration.UI_MODE_NIGHT_NO
            Appearance.Dark -> Configuration.UI_MODE_NIGHT_YES
        }
        if (nightMode == null) {
            configuration
        } else {
            Configuration(configuration).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or nightMode
            }
        }
    }
    CompositionLocalProvider(
        LocalDensity provides overriddenDensity,
        LocalConfiguration provides overriddenConfiguration,
        content = content,
    )
}

/**
 * Also sets the app's night mode on Android 12+, so themes resolved outside `DevSheet` and views
 * follow the choice. The system keeps this per app; "System" hands control back to the device setting.
 */
internal fun applyAppNightMode(context: Context, appearance: Appearance) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
    val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager ?: return
    uiModeManager.setApplicationNightMode(
        when (appearance) {
            Appearance.System -> UiModeManager.MODE_NIGHT_AUTO
            Appearance.Light -> UiModeManager.MODE_NIGHT_NO
            Appearance.Dark -> UiModeManager.MODE_NIGHT_YES
        }
    )
}
