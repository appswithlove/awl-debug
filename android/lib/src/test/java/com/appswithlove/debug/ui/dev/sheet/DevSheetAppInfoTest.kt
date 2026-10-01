package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
// Clicks inside the bottom sheet only arrive with native graphics, as in DevSheetScreenshotTest.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class DevSheetAppInfoTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val devStore = DevStore(ApplicationProvider.getApplicationContext())

    @Test
    fun header_collapsesToOneLine_andTheChoiceIsStored() {
        openPanel()
        composeTestRule.onNodeWithText("Version: 1.0").assertExists()
        composeTestRule.onNodeWithText("App Info").assert(stateDescription("Expanded"))

        composeTestRule.onNodeWithText("App Info").performClick()
        waitForText("· Android", gone = false)

        composeTestRule.onNodeWithText("App Info").assert(stateDescription("Collapsed"))
        composeTestRule.onNodeWithText("Version: 1.0").assertDoesNotExist()
        composeTestRule.onNodeWithText("Show version overlay").assertDoesNotExist()
        composeTestRule.onNodeWithText("1.0 (1254621) · Android", substring = true).assertExists()
        composeTestRule.onNodeWithText("· Prod Release", substring = true).assertExists()
        runBlocking { devStore.appInfoExpanded.first() } shouldBe false

        composeTestRule.onNodeWithText("App Info").performClick()
        waitForText("· Android", gone = true)

        composeTestRule.onNodeWithText("Version: 1.0").assertExists()
        runBlocking { devStore.appInfoExpanded.first() } shouldBe true
    }

    /** The choice is saved in DataStore and read back from there, off the main thread. */
    private fun waitForText(text: String, gone: Boolean) {
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText(text, substring = true)).fetchSemanticsNodes().isEmpty() == gone
        }
    }

    private fun stateDescription(value: String) = SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, value)

    private fun openPanel() {
        runBlocking {
            devStore.setDevToolActivated(true)
            // DataStore is shared by all tests in this process; start expanded like a fresh install.
            devStore.setAppInfoExpanded(true)
        }
        val viewModel = DevViewModel(devStore)
        composeTestRule.setContent {
            DevSheet(viewModel = viewModel, logHistory = LogHistory(), devConfig = DevConfig.Preview) {}
        }
        composeTestRule.waitForIdle()
        viewModel.submitAction(DevAction.ShowDevSheet(show = true))
        composeTestRule.waitForIdle()
    }
}
