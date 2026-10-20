package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.LogEntry
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.appswithlove.debug.ui.theme.DevTheme
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class LogsModuleExpandTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val longText = (1..5).joinToString("\n") { "line $it" }

    @Test
    fun tap_expandsOnlyTheTappedEntry() {
        val logHistory = LogHistory().apply {
            push(LogEntry(DevLogSeverity.INFO, "first\n$longText"))
            push(LogEntry(DevLogSeverity.INFO, "second\n$longText"))
        }
        composeTestRule.setContent {
            DevTheme {
                LogsModule(logHistory = logHistory, onEntryLongPress = {}, onMaxLogsChanged = {})
            }
        }
        fun height(prefix: String) =
            composeTestRule.onNodeWithText(prefix, substring = true).fetchSemanticsNode().size.height
        val collapsedFirst = height("first")
        val collapsedSecond = height("second")

        composeTestRule.onNodeWithText("second", substring = true).performClick()
        composeTestRule.waitForIdle()

        height("second") shouldBeGreaterThan collapsedSecond
        height("first") shouldBe collapsedFirst
    }
}
