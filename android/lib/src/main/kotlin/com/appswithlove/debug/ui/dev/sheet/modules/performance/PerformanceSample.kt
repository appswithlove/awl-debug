package com.appswithlove.debug.ui.dev.sheet.modules.performance

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class PerformanceSample(
    val cpuPercent: Float,
    val usedRamMb: Long,
    val totalRamMb: Long,
    val batteryPercent: Int,
    val currentDrawMa: Int,
    val timestamp: Long = System.currentTimeMillis(),
) {
    val formattedTime: String =
        SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(timestamp))
    val ramPercent: Float get() = if (totalRamMb > 0) usedRamMb.toFloat() / totalRamMb else 0f
}
