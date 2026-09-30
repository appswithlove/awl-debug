package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.DevBridge
import com.appswithlove.debug.api.bridge.FeedbackEntry
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.LogHistory
import io.kotest.matchers.shouldBe
import io.kotest.matchers.floats.shouldBeLessThan
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(AwlDebugInternalApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevSheetFeedbackEntryTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var feedbackStarts = 0

    @After
    fun tearDown() {
        DevBridge.feedbackLauncher.value = null
    }

    private fun setSheet(triggers: Set<DevTrigger> = setOf(DevTrigger.ThreeFingerTap)): DevViewModel {
        val devStore = DevStore(ApplicationProvider.getApplicationContext())
        runBlocking { devStore.setDevToolActivated(true) }
        val viewModel = DevViewModel(devStore)
        composeTestRule.setContent {
            DevSheet(viewModel = viewModel, logHistory = LogHistory(), triggers = triggers) {
                Box(Modifier.fillMaxSize().testTag("app-content"))
            }
        }
        composeTestRule.waitForIdle()
        return viewModel
    }

    private fun registerFeedback(triggers: Set<DevTrigger> = emptySet(), pending: Int = 0) {
        DevBridge.feedbackLauncher.value = FeedbackEntry(triggers, MutableStateFlow(pending)) { feedbackStarts++ }
    }

    private fun DevViewModel.open() {
        submitAction(DevAction.ShowDevSheet(show = true))
        composeTestRule.waitForIdle()
    }

    @Test
    fun withoutFeedbackHost_showsNoEntry() {
        setSheet().open()

        composeTestRule.onNodeWithText("Send feedback").assertDoesNotExist()
    }

    @Test
    fun withFeedbackHost_showsEntrySecondWithPendingCount() {
        registerFeedback(pending = 2)
        setSheet().open()

        fun top(label: String) = composeTestRule.onNodeWithText(label).fetchSemanticsNode().positionInRoot.y
        top("App Info") shouldBeLessThan top("Send feedback")
        top("Send feedback") shouldBeLessThan top("Logs")
        composeTestRule.onNodeWithText("2 pending").assertExists()
    }

    @Test
    fun entry_closesPanelAndStartsFeedback() {
        registerFeedback()
        val viewModel = setSheet()
        viewModel.open()

        composeTestRule.onNodeWithText("Send feedback").performSemanticsAction(SemanticsActions.OnClick)
        composeTestRule.waitForIdle()

        feedbackStarts shouldBe 1
        viewModel.state.value.isShown shouldBe false
    }

    @Test
    fun triggerUsedByFeedback_doesNotOpenPanel() {
        registerFeedback(triggers = setOf(DevTrigger.TripleTap))
        val viewModel = setSheet(triggers = setOf(DevTrigger.TripleTap))

        composeTestRule.onNodeWithTag("app-content").performTouchInput {
            repeat(3) {
                down(center)
                advanceEventTime(50)
                up()
                advanceEventTime(100)
            }
        }
        composeTestRule.waitForIdle()

        viewModel.state.value.isShown shouldBe false
    }
}
