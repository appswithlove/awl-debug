package com.appswithlove.debug.feedback.reporting

import android.os.Handler
import android.os.Looper
import android.view.Choreographer

/**
 * Tracks the time between frames for the `uiFreezeMs` metric. A long gap means the main thread was blocked for that
 * long. Same measurement as the debug panel's Performance module, which reporting cannot use because it runs headless.
 */
internal class FreezeTracker {
    private var lastFrameNanos = 0L
    private var intervalMaxMs = 0L

    @Synchronized
    fun onFrame(frameTimeNanos: Long) {
        if (lastFrameNanos != 0L) {
            intervalMaxMs = maxOf(intervalMaxMs, (frameTimeNanos - lastFrameNanos) / 1_000_000L)
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
