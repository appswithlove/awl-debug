package com.appswithlove.debug.ui.dev.sheet

import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevExtensionAction
import com.appswithlove.debug.api.extension.DevExtensionItem
import com.appswithlove.debug.api.extension.DevExtensionSection
import com.appswithlove.debug.api.extension.DevTextStyle
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.LogHistory
import io.kotest.matchers.floats.shouldBeLessThan
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevSheetExtensionSectionsTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val registrations = mutableListOf<AutoCloseable>()

    @After
    fun tearDown() {
        registrations.forEach(AutoCloseable::close)
    }

    private fun register(
        id: String,
        vararg items: DevExtensionItem,
        order: Int = 0,
        claimedTriggers: Set<DevTrigger> = emptySet(),
    ): MutableStateFlow<List<DevExtensionItem>> {
        val flow = MutableStateFlow(items.toList())
        registrations += AwlDebugExtensions.register(DevExtensionSection(id, flow, order, claimedTriggers))
        return flow
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

    private fun DevViewModel.open() {
        submitAction(DevAction.ShowDevSheet(show = true))
        composeTestRule.waitForIdle()
    }

    private fun top(text: String) = composeTestRule.onNodeWithText(text).fetchSemanticsNode().positionInRoot.y

    private fun click(text: String) {
        composeTestRule.onNodeWithText(text).performSemanticsAction(SemanticsActions.OnClick)
        composeTestRule.waitForIdle()
    }

    private fun tripleTap() {
        composeTestRule.onNodeWithTag("app-content").performTouchInput {
            repeat(3) {
                down(center)
                advanceEventTime(50)
                up()
                advanceEventTime(100)
            }
        }
        composeTestRule.waitForIdle()
    }

    @Test
    fun sections_showBelowAppInfoInOrderAndFollowTheirItems() {
        register("late", DevExtensionItem.Title("Late section"), order = 20)
        val early = register("early", DevExtensionItem.Title("Early section"), order = 10)
        register("same-order", DevExtensionItem.Title("Registered later"), order = 20)
        setSheet().open()

        top("App Info") shouldBeLessThan top("Early section")
        top("Early section") shouldBeLessThan top("Late section")
        top("Late section") shouldBeLessThan top("Registered later")
        top("Registered later") shouldBeLessThan top("Logs")

        early.value = listOf(DevExtensionItem.Title("Early section"), DevExtensionItem.Text("3 waiting"))
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("3 waiting").assertExists()

        early.value = emptyList()
        composeTestRule.waitForIdle()
        composeTestRule.onNodeWithText("Early section").assertDoesNotExist()
    }

    @Test
    fun closedRegistration_removesTheSection() {
        register("gone", DevExtensionItem.Title("Temporary section"))
        setSheet().open()
        composeTestRule.onNodeWithText("Temporary section").assertExists()

        registrations.removeAt(registrations.lastIndex).close()
        composeTestRule.waitForIdle()

        composeTestRule.onNodeWithText("Temporary section").assertDoesNotExist()
    }

    @Test
    fun link_closesThePanelBeforeItRuns() {
        var runs = 0
        register("link", DevExtensionItem.Link("Open extension", badge = "2 waiting") { runs++ })
        val viewModel = setSheet()
        viewModel.open()
        composeTestRule.onNodeWithText("2 waiting").assertExists()

        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.onNodeWithText("Open extension").performSemanticsAction(SemanticsActions.OnClick)
        composeTestRule.mainClock.advanceTimeByFrame()
        runs shouldBe 0

        composeTestRule.mainClock.autoAdvance = true
        composeTestRule.waitForIdle()
        runs shouldBe 1
        viewModel.state.value.isShown shouldBe false
    }

    @Test
    fun switchAndTitleAction_reportTaps() {
        var checked: Boolean? = null
        var actionRuns = 0
        register(
            "controls",
            DevExtensionItem.Title("Extension: On", DevExtensionAction("Run now") { actionRuns++ }),
            DevExtensionItem.Switch("Send data", checked = true) { checked = it },
            DevExtensionItem.Title("Paused", DevExtensionAction("Resume", enabled = false) { actionRuns++ }),
        )
        setSheet().open()

        click("Run now")
        click("Send data")

        actionRuns shouldBe 1
        checked shouldBe false
        composeTestRule.onNodeWithText("Resume").assertIsNotEnabled()
    }

    @Test
    fun textWithCopyValue_copiesItOnTap() {
        register(
            "copy",
            DevExtensionItem.Text("Problem", DevTextStyle.Error),
            DevExtensionItem.Text("ID: abc-123", DevTextStyle.Monospace, copyValue = "abc-123"),
        )
        setSheet().open()

        click("ID: abc-123")

        val clipboard = ApplicationProvider.getApplicationContext<Context>().getSystemService(ClipboardManager::class.java)
        clipboard.primaryClip?.getItemAt(0)?.text?.toString() shouldBe "abc-123"
    }

    @Test
    fun claimedTrigger_doesNotOpenThePanel() {
        register("claims", DevExtensionItem.Title("Claims triple tap"), claimedTriggers = setOf(DevTrigger.TripleTap))
        val viewModel = setSheet(triggers = setOf(DevTrigger.TripleTap))

        tripleTap()

        viewModel.state.value.isShown shouldBe false
    }

    @Test
    fun unclaimedTrigger_opensThePanel() {
        register("claims", DevExtensionItem.Title("Claims shake"), claimedTriggers = setOf(DevTrigger.Shake))
        val viewModel = setSheet(triggers = setOf(DevTrigger.TripleTap))

        tripleTap()

        viewModel.state.value.isShown shouldBe true
    }
}
