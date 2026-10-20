package com.appswithlove.debug.ui.dev.sheet.modules.performance

import androidx.test.core.app.ApplicationProvider
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PerformanceMonitorSamplingTest {

    private val monitor = PerformanceMonitor(ApplicationProvider.getApplicationContext())

    @Test
    fun sampling_runsOnlyWhileSwitchOrOverlayIsOn() {
        monitor.isSampling shouldBe false

        monitor.setOverlayVisible(true)
        monitor.isSampling shouldBe true

        monitor.setTracking(true)
        monitor.setOverlayVisible(false)
        monitor.isSampling shouldBe true

        monitor.setTracking(false)
        monitor.isSampling shouldBe false
    }
}
