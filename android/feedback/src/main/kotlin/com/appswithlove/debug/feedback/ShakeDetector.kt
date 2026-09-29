package com.appswithlove.debug.feedback

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import kotlin.math.sqrt

private const val SHAKE_THRESHOLD_G = 2.7f
private const val SHAKE_DEBOUNCE_MS = 1_500L

/** Calls [onShake] when the acceleration exceeds [SHAKE_THRESHOLD_G], at most once per [SHAKE_DEBOUNCE_MS]. */
internal class ShakeDetector(
    private val sensorManager: SensorManager,
    private val onShake: () -> Unit,
) : SensorEventListener {
    private var lastShakeAt = 0L

    fun start() {
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
    }

    fun stop() {
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val (x, y, z) = event.values
        val gForce = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH
        val now = SystemClock.elapsedRealtime()
        if (gForce > SHAKE_THRESHOLD_G && now - lastShakeAt > SHAKE_DEBOUNCE_MS) {
            lastShakeAt = now
            onShake()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
