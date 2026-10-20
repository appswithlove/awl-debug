package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.LogHistory
import io.kotest.matchers.collections.shouldBeSortedWith
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevSheetModuleOrderTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun homePage_listsModulesInSpecOrder() {
        val devStore = DevStore(ApplicationProvider.getApplicationContext())
        runBlocking { devStore.setDevToolActivated(true) }
        val viewModel = DevViewModel(devStore)
        composeTestRule.setContent {
            DevSheet(viewModel = viewModel, logHistory = LogHistory()) {}
        }
        composeTestRule.waitForIdle()
        viewModel.submitAction(DevAction.ShowDevSheet(show = true))
        composeTestRule.waitForIdle()

        val expectedOrder = listOf(
            "App Info", "Logs", "Performance", "Permissions", "Accessibility",
            "Deeplinks", "Clear App Data", "Test Crashes",
        )
        val tops = expectedOrder.map { label ->
            composeTestRule.onNodeWithText(label).fetchSemanticsNode().positionInRoot.y
        }
        tops.shouldBeSortedWith(compareBy { it })
    }
}
