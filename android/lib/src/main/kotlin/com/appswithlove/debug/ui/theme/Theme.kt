package com.appswithlove.debug.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

private val LocalAppColors = staticCompositionLocalOf {
    AppColors(
        background = Color.Unspecified,
        dialog = Color.Unspecified,
        iconSubtle = Color.Unspecified,
        info = Color.Unspecified,
        warning = Color.Unspecified,
        positive = Color.Unspecified,
        error = Color.Unspecified,
    )
}

private val DarkColorScheme = darkColorScheme()
private val LightColorScheme = lightColorScheme()

/**
 * Theme for the debug drawer.
 *
 * [colorScheme], [typography] and [shapes] default to the ambient [MaterialTheme] values (the host
 * app's, when the drawer is rendered inside it). Pass `null` for [colorScheme] to fall back to a
 * neutral Material default instead of inheriting the host colors.
 */
@Composable
fun DevTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    colorScheme: ColorScheme? = null,
    typography: Typography = MaterialTheme.typography,
    shapes: Shapes = MaterialTheme.shapes,
    content: @Composable () -> Unit
) {
    val appColors = if (darkTheme) {
        AppColors(
            background = BackgroundDark,
            dialog = DialogDark,
            iconSubtle = IconSubtleDark,
            info = InfoDark,
            warning = WarningDark,
            positive = Positive,
            error = ErrorDark
        )
    } else {
        AppColors(
            background = BackgroundLight,
            dialog = DialogLight,
            iconSubtle = IconSubtleLight,
            info = InfoLight,
            warning = WarningLight,
            positive = Positive,
            error = ErrorLight
        )
    }

    val resolvedColorScheme = colorScheme ?: if (darkTheme) DarkColorScheme else LightColorScheme

    CompositionLocalProvider(
        LocalAppColors provides appColors,
    ) {
        MaterialTheme(
            colorScheme = resolvedColorScheme,
            typography = typography,
            shapes = shapes,
            content = content,
        )
    }
}

object AppTheme {
    val colors: AppColors
        @Composable
        get() = LocalAppColors.current
}
