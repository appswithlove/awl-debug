package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.appswithlove.debug.ui.theme.DevTheme
import io.kotest.matchers.shouldBe
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ClearAppDataModuleTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var clearCount = 0

    private fun render() {
        composeTestRule.setContent { DevTheme { ClearAppDataModule(onClear = { clearCount++ }) } }
        composeTestRule.onNodeWithText("Clear app data").performClick()
        composeTestRule.onNodeWithText("Clear app data?").assertExists()
    }

    @Test
    fun cancel_clearsNothing() {
        render()

        composeTestRule.onNodeWithText("Cancel").performClick()

        clearCount shouldBe 0
        composeTestRule.onNodeWithText("Clear app data?").assertDoesNotExist()
    }

    @Test
    fun confirm_clearsOnce() {
        render()

        composeTestRule.onNodeWithText("Clear").performClick()

        clearCount shouldBe 1
    }
}
