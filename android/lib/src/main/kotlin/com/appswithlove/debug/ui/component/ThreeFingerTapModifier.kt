package com.appswithlove.debug.ui.component

import android.os.Build
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput

private val isEmulator = Build.FINGERPRINT.startsWith("generic")
    || Build.FINGERPRINT.startsWith("unknown")
    || Build.MODEL.contains("Emulator")
    || Build.MODEL.contains("Android SDK built for x86")
    || Build.MODEL.startsWith("sdk_gphone")
    || Build.DEVICE.startsWith("emulator")
    || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))

fun Modifier.threeFingerTap(onThreeFingerTap: () -> Unit): Modifier {
    val requiredPointers = if (isEmulator) 2 else 3
    return this.pointerInput(Unit) {
        awaitEachGesture {
            do {
                val event = awaitPointerEvent()
                val pointerCount = event.changes.count { it.pressed }
                if (pointerCount == requiredPointers) {
                    onThreeFingerTap()
                    break
                }
            } while (event.changes.any { it.pressed })
        }
    }
}
