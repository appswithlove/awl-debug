package com.appswithlove.debug.ui.dev.sheet.modules.session

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.appswithlove.debug.api.session.SessionProvider
import com.appswithlove.debug.ui.theme.DevTheme
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SessionDetailModuleTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val token = "eyJhbGciOiJIUzI1NiJ9.payload.signature"

    private fun render(provider: SessionProvider) {
        composeTestRule.setContent {
            DevTheme { SessionDetailModule(sessionManager = SessionManager(listOf(provider))) }
        }
        // The token is collected off the main thread.
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("Logged in")).fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test
    fun failingAction_showsErrorAndEnablesButtonAgain() {
        render(object : SessionProvider {
            override val label = "Access Token"
            override val token = MutableStateFlow<String?>(this@SessionDetailModuleTest.token)
            override val onRefresh: suspend () -> Unit = { error("boom") }
        })

        composeTestRule.onNodeWithText("Refresh").performClick()
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("Action failed: boom")).fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithText("Refresh").assertIsEnabled()
    }

    @Test
    fun providerWithoutSetToken_hidesEditAndDelete_andMasksTokenUntilRevealed() {
        render(object : SessionProvider {
            override val label = "Access Token"
            override val token = MutableStateFlow<String?>(this@SessionDetailModuleTest.token)
        })

        composeTestRule.onNodeWithText("Edit").assertDoesNotExist()
        composeTestRule.onNodeWithText("Delete").assertDoesNotExist()
        composeTestRule.onNodeWithText("eyJhbG…ture").assertExists()

        composeTestRule.onNodeWithContentDescription("Reveal token").performClick()

        composeTestRule.onNodeWithText(token).assertExists()
    }

    @Test
    fun withoutProviders_showsHowToAddOne() {
        composeTestRule.setContent {
            DevTheme { SessionDetailModule(sessionManager = SessionManager(emptyList())) }
        }

        composeTestRule.onNodeWithText("No session tokens configured").assertExists()
        composeTestRule.onNodeWithText("sessionProviders = listOf(", substring = true).assertExists()
        composeTestRule.onNodeWithText("Copy code").assertIsEnabled()
        composeTestRule.onNodeWithText("Logged out").assertDoesNotExist()
    }
}
