package com.appswithlove.debug.ui.dev.recording

import android.view.MotionEvent
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TouchTrackerTest {

    @Test
    fun cancel_endsEveryFingerSoNoneStaysInLaterFrames() {
        val tracker = TouchTracker()
        tracker.onTouch(twoFingerEvent(MotionEvent.ACTION_MOVE), nowMillis = 1L)
        tracker.drain().map { it.phase } shouldBe listOf(TouchPhase.Moved, TouchPhase.Moved)

        tracker.onTouch(twoFingerEvent(MotionEvent.ACTION_CANCEL), nowMillis = 2L)

        tracker.drain().map { it.phase } shouldBe listOf(TouchPhase.Ended, TouchPhase.Ended)
        tracker.drain() shouldBe emptyList()
    }

    private fun twoFingerEvent(action: Int): MotionEvent {
        val ids = arrayOf(
            MotionEvent.PointerProperties().apply { id = 0 },
            MotionEvent.PointerProperties().apply { id = 1 },
        )
        val coords = arrayOf(
            MotionEvent.PointerCoords().apply { x = 10f; y = 20f },
            MotionEvent.PointerCoords().apply { x = 30f; y = 40f },
        )
        return MotionEvent.obtain(0L, 0L, action, 2, ids, coords, 0, 0, 1f, 1f, 0, 0, 0, 0)
    }
}
