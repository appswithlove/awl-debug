package com.appswithlove.debug.ui.dev.sheet

import android.hardware.SensorManager.GRAVITY_EARTH
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.component.ShakeDetector
import com.appswithlove.debug.ui.dev.log.LogHistory
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevTriggerTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val devStore = DevStore(ApplicationProvider.getApplicationContext())

    private fun setSheet(
        triggers: Set<DevTrigger>,
        activated: Boolean = true,
        isAlwaysActive: Boolean = false,
    ): DevViewModel {
        runBlocking { devStore.setDevToolActivated(activated) }
        val viewModel = DevViewModel(devStore)
        composeTestRule.setContent {
            DevSheet(
                viewModel = viewModel,
                logHistory = LogHistory(),
                triggers = triggers,
                isAlwaysActive = isAlwaysActive,
            ) {
                Box(Modifier.fillMaxSize().testTag("app-content"))
            }
        }
        composeTestRule.waitForIdle()
        return viewModel
    }

    private fun tripleTap() = composeTestRule.onNodeWithTag("app-content").performTouchInput {
        repeat(3) {
            down(center)
            advanceEventTime(50)
            up()
            advanceEventTime(100)
        }
    }

    private fun threeFingerTap() = composeTestRule.onNodeWithTag("app-content").performTouchInput {
        down(0, center)
        down(1, center + Offset(40f, 0f))
        down(2, center + Offset(80f, 0f))
        advanceEventTime(50)
        up(0)
        up(1)
        up(2)
    }

    private fun DevViewModel.isShown(): Boolean {
        composeTestRule.waitForIdle()
        return state.value.isShown
    }

    @Test
    fun tripleTap_whenEnabled_opensSheet() {
        val viewModel = setSheet(setOf(DevTrigger.TripleTap))
        tripleTap()
        viewModel.isShown() shouldBe true
    }

    @Test
    fun threeFingerTap_whenNotConfigured_doesNothing() {
        val viewModel = setSheet(setOf(DevTrigger.TripleTap))
        threeFingerTap()
        viewModel.isShown() shouldBe false
    }

    @Test
    fun threeFingerTap_whenEnabled_opensSheet() {
        val viewModel = setSheet(setOf(DevTrigger.ThreeFingerTap))
        threeFingerTap()
        viewModel.isShown() shouldBe true
    }

    @Test
    fun trigger_whileDeactivated_doesNothing() {
        val deactivated = setSheet(setOf(DevTrigger.TripleTap), activated = false)
        tripleTap()
        deactivated.isShown() shouldBe false
    }

    @Test
    fun trigger_withAlwaysActive_opensWithoutActivation() {
        val viewModel = setSheet(setOf(DevTrigger.TripleTap), activated = false, isAlwaysActive = true)
        tripleTap()
        viewModel.isShown() shouldBe true
        runBlocking { devStore.isDevToolActivated.first() } shouldBe false
    }

    @Test
    fun shakeDetector_firesAboveThresholdOncePerDebounce() {
        var shakes = 0
        val detector = ShakeDetector { shakes++ }
        val strong = 3f * GRAVITY_EARTH

        detector.onAcceleration(0f, 0f, GRAVITY_EARTH, timeMs = 0)
        detector.onAcceleration(strong, 0f, 0f, timeMs = 100)
        detector.onAcceleration(strong, 0f, 0f, timeMs = 1_000)
        detector.onAcceleration(strong, 0f, 0f, timeMs = 1_700)

        shakes shouldBe 2
    }
}
