package com.appswithlove.debug.feedback

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

// Neutral colors of the feedback screen, the same values as the debug panel of the `debug` artifact,
// which this module does not depend on. Text colors reach 4.5:1 on the background.
private val Ink = Color(0xFF1B1B1D)
private val Paper = Color(0xFFE6E6E8)
private val InkVariant = Color(0xFF505055)
private val PaperVariant = Color(0xFFC4C4C9)
private val DarkBackground = Color(0xFF212224)
private val DarkContainer = Color(0xFF3A3B3E)

internal val FeedbackLightColors: ColorScheme = lightColorScheme(
    primary = Ink,
    onPrimary = Color.White,
    primaryContainer = Paper,
    onPrimaryContainer = Ink,
    secondaryContainer = Paper,
    onSecondaryContainer = Ink,
    background = Color.White,
    onBackground = Ink,
    surface = Color.White,
    onSurface = Ink,
    surfaceVariant = Paper,
    onSurfaceVariant = InkVariant,
    surfaceTint = Ink,
    outline = Color(0xFF76767B),
    outlineVariant = Color(0xFFC7C7CC),
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFF7F7F8),
    surfaceContainer = Color(0xFFF2F2F3),
    surfaceContainerHigh = Color(0xFFECECEE),
    surfaceContainerHighest = Paper,
    error = Color(0xFFC43B3B),
)

internal val FeedbackDarkColors: ColorScheme = darkColorScheme(
    primary = Paper,
    onPrimary = Ink,
    primaryContainer = DarkContainer,
    onPrimaryContainer = Paper,
    secondaryContainer = DarkContainer,
    onSecondaryContainer = Paper,
    background = DarkBackground,
    onBackground = Paper,
    surface = DarkBackground,
    onSurface = Paper,
    surfaceVariant = DarkContainer,
    onSurfaceVariant = PaperVariant,
    surfaceTint = Paper,
    outline = Color(0xFF8E8E93),
    outlineVariant = Color(0xFF45464A),
    surfaceContainerLowest = Color(0xFF1A1B1D),
    surfaceContainerLow = Color(0xFF26272A),
    surfaceContainer = Color(0xFF2A2B2E),
    surfaceContainerHigh = Color(0xFF27292A),
    surfaceContainerHighest = DarkContainer,
    error = Color(0xFFFF6B6B),
)
