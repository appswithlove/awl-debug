package com.appswithlove.debug.reporting

import android.content.Context
import android.os.BatteryManager
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import com.appswithlove.debug.ui.dev.sheet.modules.performance.ChoreographerFrameSource
import com.appswithlove.debug.ui.dev.sheet.modules.performance.FreezeTracker
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * Takes a [ReportingMetricSample] every [intervalMs] while the app is in the foreground, without any
 * UI: CPU as the mean over the interval normalised over all cores, RAM as total PSS, battery level and
 * the longest frame of the interval.
 */
internal class ReportingMetricsSampler(
    context: Context,
    private val executor: ScheduledExecutorService,
    private val onSample: (ReportingMetricSample) -> Unit,
    private val intervalMs: Long = INTERVAL_MS,
) {
    private val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
    private val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
    private val freezeTracker = FreezeTracker()
    private val frameSource = ChoreographerFrameSource(freezeTracker)
    private var task: ScheduledFuture<*>? = null
    private var previousCpuMs = 0L
    private var previousWallMs = 0L

    /** Call on the executor thread. */
    fun start() {
        if (task != null) return
        previousCpuMs = Process.getElapsedCpuTime()
        previousWallMs = SystemClock.elapsedRealtime()
        freezeTracker.reset()
        frameSource.start()
        task = executor.scheduleWithFixedDelay({ sample() }, intervalMs, intervalMs, TimeUnit.MILLISECONDS)
    }

    /** Call on the executor thread. */
    fun stop() {
        task?.cancel(false)
        task = null
        frameSource.stop()
    }

    private fun sample() {
        val cpuMs = Process.getElapsedCpuTime()
        val wallMs = SystemClock.elapsedRealtime()
        val wallDelta = wallMs - previousWallMs
        val cpuPercent = if (wallDelta > 0) (cpuMs - previousCpuMs).toDouble() / wallDelta / cores * 100.0 else null
        previousCpuMs = cpuMs
        previousWallMs = wallMs
        val memoryInfo = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
        val battery = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        onSample(
            ReportingMetricSample(
                timestampMillis = System.currentTimeMillis(),
                cpuPercent = cpuPercent?.coerceIn(0.0, 100.0),
                ramBytes = memoryInfo.totalPss.toLong().takeIf { it > 0 }?.times(1024),
                batteryPercent = battery?.takeIf { it in 0..100 },
                uiFreezeMs = freezeTracker.takeIntervalMaxMs(),
            ),
        )
    }

    companion object {
        const val INTERVAL_MS = 5_000L
    }
}
