package com.appswithlove.debug.feedback

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class FeedbackNoOpTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val config = FeedbackConfig(
        endpoint = "https://feedback.example.com",
        appKey = "app-key",
        appVersion = "1.0",
        buildNumber = "1",
        environment = "test",
    )

    @Test
    fun feedbackHost_inNoOp_rendersContentAndLauncherRendersNothing() {
        composeTestRule.setContent {
            FeedbackHost(config = config) {
                Column {
                    Box(Modifier.fillMaxSize().testTag("app-content"))
                    FeedbackLauncher(Modifier.testTag("launcher"))
                }
            }
        }

        composeTestRule.onNodeWithTag("app-content").assertIsDisplayed()
        composeTestRule.onAllNodesWithTag("launcher").assertCountEquals(0)
    }
}
