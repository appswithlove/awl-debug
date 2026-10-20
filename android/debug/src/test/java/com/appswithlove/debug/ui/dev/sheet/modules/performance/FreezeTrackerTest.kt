package com.appswithlove.debug.ui.dev.sheet.modules.performance

import io.kotest.matchers.shouldBe
import org.junit.Test

class FreezeTrackerTest {

    private val tracker = FreezeTracker()

    private fun frames(vararg millis: Long) = millis.forEach { tracker.onFrame(it * 1_000_000L) }

    @Test
    fun onFrame_blockedMainThread_countsOneFreezeWithItsDuration() {
        frames(0, 16, 32, 1_532, 1_548)

        tracker.freezeCount shouldBe 1
        tracker.longestFreezeMs shouldBe 1_500L
        tracker.takeIntervalMaxMs() shouldBe 1_500L
        tracker.takeIntervalMaxMs() shouldBe 0L
    }

    @Test
    fun onFrame_slowFramesBelowThreshold_areNoFreeze() {
        frames(0, 400, 1_000)

        tracker.freezeCount shouldBe 0
        tracker.takeIntervalMaxMs() shouldBe 600L
    }
}
