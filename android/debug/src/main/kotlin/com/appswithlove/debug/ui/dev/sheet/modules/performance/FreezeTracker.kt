package com.appswithlove.debug.ui.dev.sheet.modules.performance

import android.os.Handler
import android.os.Looper
import android.view.Choreographer

/** A frame that takes longer than this counts as a UI freeze. */
internal const val FREEZE_THRESHOLD_MS = 700L

/**
 * Tracks the time between frames. [onFrame] gets the frame times in order; a long gap means the main
 * thread was blocked for that long.
 */
internal class FreezeTracker {
    private var lastFrameNanos = 0L
    private var intervalMaxMs = 0L

    var freezeCount = 0
        private set
    var longestFreezeMs = 0L
        private set

    @Synchronized
    fun onFrame(frameTimeNanos: Long) {
        if (lastFrameNanos != 0L) {
            val gapMs = (frameTimeNanos - lastFrameNanos) / 1_000_000L
            intervalMaxMs = maxOf(intervalMaxMs, gapMs)
            if (gapMs > FREEZE_THRESHOLD_MS) {
                freezeCount++
                longestFreezeMs = maxOf(longestFreezeMs, gapMs)
            }
        }
        lastFrameNanos = frameTimeNanos
    }

    /** Longest frame since the previous call, in milliseconds. */
    @Synchronized
    fun takeIntervalMaxMs(): Long = intervalMaxMs.also { intervalMaxMs = 0L }

    @Synchronized
    fun reset() {
        lastFrameNanos = 0L
        intervalMaxMs = 0L
        freezeCount = 0
        longestFreezeMs = 0L
    }
}

/** Feeds [tracker] from the main thread's [Choreographer] between [start] and [stop]. */
internal class ChoreographerFrameSource(private val tracker: FreezeTracker) : Choreographer.FrameCallback {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var running = false

    fun start() {
        mainHandler.post {
            if (!running) {
                running = true
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
    }

    fun stop() {
        mainHandler.post {
            running = false
            Choreographer.getInstance().removeFrameCallback(this)
        }
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (!running) return
        tracker.onFrame(frameTimeNanos)
        Choreographer.getInstance().postFrameCallback(this)
    }
}
