package com.appswithlove.debug.ui.dev.recording

import android.annotation.SuppressLint
import android.view.MotionEvent
import android.view.Window

internal enum class TouchPhase { Began, Moved, Ended }

/** A touch in window pixels. */
internal data class TouchPoint(val phase: TouchPhase, val x: Float, val y: Float, val timeMillis: Long)

/**
 * Collects touches between two frames: every start and end, plus the latest position of each finger
 * that is still down. Main thread only.
 */
internal class TouchTracker {
    private val events = mutableListOf<TouchPoint>()
    private val moving = linkedMapOf<Int, TouchPoint>()

    fun onTouch(event: MotionEvent, nowMillis: Long) {
        val index = event.actionIndex
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN ->
                events += TouchPoint(TouchPhase.Began, event.getX(index), event.getY(index), nowMillis)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                moving.remove(event.getPointerId(index))
                events += TouchPoint(TouchPhase.Ended, event.getX(index), event.getY(index), nowMillis)
            }
            MotionEvent.ACTION_MOVE -> for (pointer in 0 until event.pointerCount) {
                moving[event.getPointerId(pointer)] =
                    TouchPoint(TouchPhase.Moved, event.getX(pointer), event.getY(pointer), nowMillis)
            }
        }
    }

    /** Touches since the previous call; fingers still down stay in the next frame. */
    fun drain(): List<TouchPoint> = (events + moving.values).also { events.clear() }

    fun clear() {
        events.clear()
        moving.clear()
    }
}

/** Passes every call to [delegate] and reports touches of the activity window to [onTouch]. */
internal class RecordingWindowCallback(
    val delegate: Window.Callback,
    private val onTouch: (MotionEvent) -> Unit,
) : Window.Callback by delegate {
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        onTouch(event)
        return delegate.dispatchTouchEvent(event)
    }

    // Default methods of Window.Callback, forwarded explicitly; the framework calls them only on API levels that have them.
    @SuppressLint("NewApi")
    override fun onPointerCaptureChanged(hasCapture: Boolean) {
        delegate.onPointerCaptureChanged(hasCapture)
    }

    @SuppressLint("NewApi")
    override fun onProvideKeyboardShortcuts(
        data: MutableList<android.view.KeyboardShortcutGroup>?,
        menu: android.view.Menu?,
        deviceId: Int,
    ) {
        delegate.onProvideKeyboardShortcuts(data, menu, deviceId)
    }
}
