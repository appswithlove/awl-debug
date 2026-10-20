package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevExtensionAction
import com.appswithlove.debug.api.extension.DevExtensionItem
import com.appswithlove.debug.api.extension.DevExtensionSection
import com.appswithlove.debug.api.extension.DevTextStyle
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.github.takahirom.roborazzi.ExperimentalRoborazziApi
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureScreenRoboImage
import kotlinx.coroutines.flow.MutableStateFlow
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
    fun homeAppInfoCollapsed() {
        openPanel()
        composeTestRule.onNodeWithText("App Info").performClick()
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("· Android", substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
        captureScreenRoboImage("src/test/screenshots/DevSheet_home_app_info_collapsed.png")
    }

    @Test
    @Config(fontScale = 2f)
    fun homeAppInfoCollapsedLargeFont() {
        openPanel()
        composeTestRule.onNodeWithText("App Info").performClick()
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("· Android", substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
        captureScreenRoboImage("src/test/screenshots/DevSheet_home_app_info_collapsed_font200.png")
    }

    @Test
    fun homeWithExtensionSections() {
        val status = DevExtensionSection(
            id = "status",
            order = 10,
            items = MutableStateFlow(
                listOf(
                    DevExtensionItem.Title("Demo extension: On", DevExtensionAction("Run now") {}),
                    DevExtensionItem.Text("Last run failed.", DevTextStyle.Error),
                    DevExtensionItem.Text("12 waiting · Last run 10:15:30"),
                    DevExtensionItem.Text("ID: 3f2a9c1e", DevTextStyle.Monospace, copyValue = "3f2a9c1e"),
                    DevExtensionItem.Switch("Enabled on this device", checked = true) {},
                ),
            ),
        )
        val link = DevExtensionSection(
            id = "link",
            order = 20,
            items = MutableStateFlow(listOf(DevExtensionItem.Link("Open demo", badge = "2 waiting") {})),
        )
        val registrations = listOf(AwlDebugExtensions.register(status), AwlDebugExtensions.register(link))
        try {
            openPanel()
            captureScreenRoboImage("src/test/screenshots/DevSheet_home_extensions.png")
        } finally {
            registrations.forEach(AutoCloseable::close)
        }
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
