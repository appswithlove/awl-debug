package com.appswithlove.debug.ui.component

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.SystemClock
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import kotlin.math.sqrt

/** Fires [onShake] when the acceleration exceeds [thresholdG], at most once per [debounceMs]. */
internal class ShakeDetector(
    private val thresholdG: Float = 2.7f,
    private val debounceMs: Long = 1_500,
    private val onShake: () -> Unit,
) {
    private var lastShakeMs = Long.MIN_VALUE

    fun onAcceleration(x: Float, y: Float, z: Float, timeMs: Long) {
        val gForce = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH
        if (gForce < thresholdG) return
        if (lastShakeMs != Long.MIN_VALUE && timeMs - lastShakeMs < debounceMs) return
        lastShakeMs = timeMs
        onShake()
    }
}

/** Listens to the accelerometer while in composition. */
@Composable
internal fun ShakeTrigger(onShake: () -> Unit) {
    val context = LocalContext.current
    val currentOnShake by rememberUpdatedState(onShake)
    DisposableEffect(context) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val detector = ShakeDetector { currentOnShake() }
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                detector.onAcceleration(event.values[0], event.values[1], event.values[2], SystemClock.elapsedRealtime())
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        if (accelerometer != null) {
            sensorManager.registerListener(listener, accelerometer, SensorManager.SENSOR_DELAY_UI)
        }
        onDispose { sensorManager?.unregisterListener(listener) }
    }
}

/** Listens for system screenshots of the host activity while in composition. Android 14+ only. */
@Composable
internal fun ScreenshotTrigger(onScreenshot: () -> Unit) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
    val activity = LocalContext.current.findActivity() ?: return
    val currentOnScreenshot by rememberUpdatedState(onScreenshot)
    DisposableEffect(activity) {
        val callback = Activity.ScreenCaptureCallback { currentOnScreenshot() }
        activity.registerScreenCaptureCallback(activity.mainExecutor, callback)
        onDispose { activity.unregisterScreenCaptureCallback(callback) }
    }
}

internal tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
