package com.appswithlove.debug.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

internal val BackgroundLight = Color(0xFFFFFFFF)
internal val BackgroundDark = Color(0xFF212224)
internal val DialogLight = Color(0xFFE7E7E7)
internal val DialogDark = Color(0xFF27292A)
internal val InfoLight = Color(0xFF6439AF)
internal val InfoDark = Color(0xFF6F49B0)
internal val WarningLight = Color(0xFFD29947)
internal val WarningDark = Color(0xFFF3B45B)
internal val ErrorLight = Color(0xFFC43B3B)
internal val ErrorDark = Color(0xFFDA3434)
internal val IconSubtleLight = Color(0x85404242)
internal val IconSubtleDark = Color(0x85ABB6B6)
internal val Positive = Color(0xFF4CAF50)

@Immutable
internal data class AppColors(
    val background: Color,
    val dialog: Color,
    val iconSubtle: Color,
    val info: Color,
    val warning: Color,
    val positive: Color,
    val error: Color,
)
