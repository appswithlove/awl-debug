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
class TestCrashesModuleTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val crashes = mutableListOf<TestCrash>()

    private fun render() {
        composeTestRule.setContent { DevTheme { TestCrashesModule(crash = { crashes += it }) } }
        composeTestRule.onNodeWithText("Simulate crash - Index out of bounds").performClick()
        composeTestRule.onNodeWithText("Crash the app now?").assertExists()
    }

    @Test
    fun cancel_doesNotCrash() {
        render()

        composeTestRule.onNodeWithText("Cancel").performClick()

        crashes shouldBe emptyList()
        composeTestRule.onNodeWithText("Crash the app now?").assertDoesNotExist()
    }

    @Test
    fun confirm_crashesOnce() {
        render()

        composeTestRule.onNodeWithText("Crash").performClick()

        crashes shouldBe listOf(TestCrash.IndexOutOfBounds)
    }
}
