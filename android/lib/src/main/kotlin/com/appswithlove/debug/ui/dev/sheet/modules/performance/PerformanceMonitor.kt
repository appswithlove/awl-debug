package com.appswithlove.debug.ui.dev.sheet.modules.performance

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

private const val MAX_SAMPLES = 60
private const val SAMPLE_INTERVAL_MS = 2000L

class PerformanceMonitor(context: Context) {
    private val activityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val batteryManager =
        context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var samplingJob: Job? = null

    private val _isTracking = MutableStateFlow(false)
    val isTracking = _isTracking.asStateFlow()

    private val _samples = MutableStateFlow<List<PerformanceSample>>(emptyList())
    val samples = _samples.asStateFlow()

    private val _startBatteryPercent = MutableStateFlow<Int?>(null)
    val startBatteryPercent = _startBatteryPercent.asStateFlow()

    fun setTracking(enabled: Boolean) {
        _isTracking.value = enabled
        if (enabled) {
            _startBatteryPercent.value =
                batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    .takeIf { it >= 0 }
            startSampling()
        } else {
            samplingJob?.cancel()
        }
    }

    fun clear() {
        _samples.value = emptyList()
    }

    private fun startSampling() {
        samplingJob?.cancel()
        samplingJob = scope.launch {
            var prevCpu = Process.getElapsedCpuTime()
            var prevWall = SystemClock.elapsedRealtime()

            while (true) {
                delay(SAMPLE_INTERVAL_MS)

                val currCpu = Process.getElapsedCpuTime()
                val currWall = SystemClock.elapsedRealtime()
                val wallDelta = currWall - prevWall
                val cpuPercent = if (wallDelta > 0) {
                    ((currCpu - prevCpu).toFloat() / wallDelta * 100f).coerceIn(0f, 100f)
                } else {
                    0f
                }

                val memInfo = Debug.MemoryInfo()
                Debug.getMemoryInfo(memInfo)
                val usedRamMb = memInfo.totalPss / 1024L
                val ramInfo = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(ramInfo)
                val totalRamMb = ramInfo.totalMem / 1_048_576L

                val batteryPercent =
                    batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        .coerceAtLeast(0)
                val currentDrawMa = kotlin.math.abs(
                    batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                ) / 1000

                _samples.value = (_samples.value + PerformanceSample(
                    cpuPercent = cpuPercent,
                    usedRamMb = usedRamMb,
                    totalRamMb = totalRamMb,
                    batteryPercent = batteryPercent,
                    currentDrawMa = currentDrawMa,
                )).let { if (it.size > MAX_SAMPLES) it.takeLast(MAX_SAMPLES) else it }

                prevCpu = currCpu
                prevWall = currWall
            }
        }
    }
}
