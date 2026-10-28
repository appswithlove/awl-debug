package com.appswithlove.debug.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

internal val BackgroundLight = Color(0xFFFFFFFF)
internal val BackgroundDark = Color(0xFF212224)
internal val DialogLight = Color(0xFFE7E7E7)
internal val DialogDark = Color(0xFF27292A)
internal val InfoLight = Color(0xFF6439AF)
internal val InfoDark = Color(0xFFB39DDB)
internal val WarningLight = Color(0xFF9A6200)
internal val WarningDark = Color(0xFFF3B45B)
internal val ErrorLight = Color(0xFFC43B3B)
internal val ErrorDark = Color(0xFFFF6B6B)
internal val IconSubtleLight = Color(0x85404242)
internal val IconSubtleDark = Color(0x85ABB6B6)
internal val PositiveLight = Color(0xFF2E7D32)
internal val PositiveDark = Color(0xFF4CAF50)
internal val RedirectLight = Color(0xFF2F6FDE)
internal val RedirectDark = Color(0xFF5B8DEF)

@Immutable
internal data class AppColors(
    val background: Color,
    val dialog: Color,
    val iconSubtle: Color,
    val info: Color,
    val warning: Color,
    val positive: Color,
    val error: Color,
    val redirect: Color,
)

private val Ink = Color(0xFF1B1B1D)
private val Paper = Color(0xFFE6E6E8)

/**
 * Neutral Material color scheme of the sheet: the monochrome look of the SDK's own controls also applies to
 * Material components (text buttons, checkboxes, dialogs). Text colors reach 4.5:1 on the background.
 */
internal val DevLightColorScheme: ColorScheme = lightColorScheme(
    primary = Ink,
    onPrimary = BackgroundLight,
    primaryContainer = Paper,
    onPrimaryContainer = Ink,
    inversePrimary = Color(0xFFC7C7CC),
    secondary = Color(0xFF505055),
    onSecondary = BackgroundLight,
    secondaryContainer = Paper,
    onSecondaryContainer = Ink,
    tertiary = Color(0xFF505055),
    onTertiary = BackgroundLight,
    tertiaryContainer = Paper,
    onTertiaryContainer = Ink,
    background = BackgroundLight,
    onBackground = Ink,
    surface = BackgroundLight,
    onSurface = Ink,
    surfaceVariant = Paper,
    onSurfaceVariant = Color(0xFF505055),
    surfaceTint = Ink,
    inverseSurface = Color(0xFF303033),
    inverseOnSurface = Color(0xFFF2F2F3),
    error = ErrorLight,
    outline = Color(0xFF76767B),
    outlineVariant = Color(0xFFC7C7CC),
    surfaceBright = BackgroundLight,
    surfaceDim = Color(0xFFDADADC),
    surfaceContainerLowest = BackgroundLight,
    surfaceContainerLow = Color(0xFFF7F7F8),
    surfaceContainer = Color(0xFFF2F2F3),
    surfaceContainerHigh = Color(0xFFECECEE),
    surfaceContainerHighest = Paper,
)

internal val DevDarkColorScheme: ColorScheme = darkColorScheme(
    primary = Paper,
    onPrimary = Ink,
    primaryContainer = Color(0xFF3A3B3E),
    onPrimaryContainer = Paper,
    inversePrimary = Color(0xFF505055),
    secondary = Color(0xFFC4C4C9),
    onSecondary = Ink,
    secondaryContainer = Color(0xFF3A3B3E),
    onSecondaryContainer = Paper,
    tertiary = Color(0xFFC4C4C9),
    onTertiary = Ink,
    tertiaryContainer = Color(0xFF3A3B3E),
    onTertiaryContainer = Paper,
    background = BackgroundDark,
    onBackground = Paper,
    surface = BackgroundDark,
    onSurface = Paper,
    surfaceVariant = Color(0xFF3A3B3E),
    onSurfaceVariant = Color(0xFFC4C4C9),
    surfaceTint = Paper,
    inverseSurface = Paper,
    inverseOnSurface = Color(0xFF303033),
    error = ErrorDark,
    outline = Color(0xFF8E8E93),
    outlineVariant = Color(0xFF45464A),
    surfaceBright = Color(0xFF3A3B3E),
    surfaceDim = Color(0xFF1A1B1D),
    surfaceContainerLowest = Color(0xFF1A1B1D),
    surfaceContainerLow = Color(0xFF26272A),
    surfaceContainer = Color(0xFF2A2B2E),
    surfaceContainerHigh = DialogDark,
    surfaceContainerHighest = Color(0xFF3A3B3E),
)
