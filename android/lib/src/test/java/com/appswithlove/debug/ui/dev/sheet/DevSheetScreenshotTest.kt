package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.github.takahirom.roborazzi.ExperimentalRoborazziApi
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureScreenRoboImage
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** The panel is a bottom sheet in its own window, so these capture the whole screen. */
@OptIn(ExperimentalRoborazziApi::class)
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class DevSheetScreenshotTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun home() {
        openPanel()
        captureScreenRoboImage("src/test/screenshots/DevSheet_home.png")
    }

    @Test
    @Config(qualifiers = "+night")
    fun homeDark() {
        openPanel()
        captureScreenRoboImage("src/test/screenshots/DevSheet_home_dark.png")
    }

    @Test
    @Config(fontScale = 2f)
    fun homeLargeFont() {
        openPanel()
        captureScreenRoboImage("src/test/screenshots/DevSheet_home_font200.png")
    }

    @Test
    @Config(fontScale = 2f)
    fun moduleHeaderLargeFont() {
        openPanel()
        composeTestRule.onNodeWithText("Performance").performClick()
        composeTestRule.waitForIdle()
        captureScreenRoboImage("src/test/screenshots/DevSheet_performance_font200.png")
    }

    private fun openPanel() {
        val devStore = DevStore(ApplicationProvider.getApplicationContext())
        runBlocking { devStore.setDevToolActivated(true) }
        val viewModel = DevViewModel(devStore)
        composeTestRule.setContent {
            DevSheet(viewModel = viewModel, logHistory = LogHistory(), devConfig = DevConfig.Preview) {}
        }
        composeTestRule.waitForIdle()
        viewModel.submitAction(DevAction.ShowDevSheet(show = true))
        composeTestRule.waitForIdle()
    }
}
