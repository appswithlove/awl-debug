package com.appswithlove.debug.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

val BackgroundLight = Color(0xFFFFFFFF)
val BackgroundDark = Color(0xFF212224)
val DialogLight = Color(0xFFE7E7E7)
val DialogDark = Color(0xFF27292A)
val InfoLight = Color(0xFF6439AF)
val InfoDark = Color(0xFF6F49B0)
val WarningLight = Color(0xFFD29947)
val WarningDark = Color(0xFFF3B45B)
val ErrorLight = Color(0xFFC43B3B)
val ErrorDark = Color(0xFFDA3434)
val IconSubtleLight = Color(0x85404242)
val IconSubtleDark = Color(0x85ABB6B6)
val Positive = Color(0xFF4CAF50)

@Immutable
data class AppColors(
    val background: Color,
    val dialog: Color,
    val iconSubtle: Color,
    val info: Color,
    val warning: Color,
    val positive: Color,
    val error: Color,
)
