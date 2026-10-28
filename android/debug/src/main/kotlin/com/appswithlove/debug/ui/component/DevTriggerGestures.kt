package com.appswithlove.debug.ui.component

import android.os.Build
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ViewConfiguration

private val isEmulator = Build.FINGERPRINT.startsWith("generic")
    || Build.FINGERPRINT.startsWith("unknown")
    || Build.MODEL.contains("Emulator")
    || Build.MODEL.contains("Android SDK built for x86")
    || Build.MODEL.startsWith("sdk_gphone")
    || Build.DEVICE.startsWith("emulator")
    || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))

internal const val TRIPLE_TAP_WINDOW_MS = 600L
private const val TRIPLE_TAP_COUNT = 3

/**
 * Detects the panel's touch triggers without consuming events, so the app's own gestures keep working.
 * Observes the [PointerEventPass.Initial] pass, which reaches this parent before its children.
 */
internal fun Modifier.devTriggerGestures(
    threeFingerTap: Boolean,
    tripleTap: Boolean,
    requiredFingers: Int = if (isEmulator) 2 else 3,
    onTrigger: () -> Unit,
): Modifier {
    if (!threeFingerTap && !tripleTap) return this
    return pointerInput(threeFingerTap, tripleTap, requiredFingers) {
        val tapTimes = ArrayDeque<Long>()
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
            var maxFingers = 1
            var moved = false
            var upTime = down.uptimeMillis
            do {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val pressed = event.changes.count { it.pressed }
                maxFingers = maxOf(maxFingers, pressed)
                if (threeFingerTap && pressed == requiredFingers) {
                    tapTimes.clear()
                    onTrigger()
                    break
                }
                event.changes.firstOrNull { it.id == down.id }?.let { change ->
                    if ((change.position - down.position).exceedsSlop(viewConfiguration)) moved = true
                    upTime = change.uptimeMillis
                }
            } while (event.changes.any { it.pressed })

            val isSingleTap = maxFingers == 1 && !moved &&
                upTime - down.uptimeMillis <= viewConfiguration.longPressTimeoutMillis
            if (!tripleTap || !isSingleTap) {
                tapTimes.clear()
                return@awaitEachGesture
            }
            tapTimes.addLast(down.uptimeMillis)
            while (tapTimes.first() < down.uptimeMillis - TRIPLE_TAP_WINDOW_MS) tapTimes.removeFirst()
            if (tapTimes.size >= TRIPLE_TAP_COUNT) {
                tapTimes.clear()
                onTrigger()
            }
        }
    }
}

private fun Offset.exceedsSlop(viewConfiguration: ViewConfiguration): Boolean =
    getDistance() > viewConfiguration.touchSlop
