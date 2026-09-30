package com.appswithlove.debug.feedback

import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevExtensionItem
import com.appswithlove.debug.api.extension.DevExtensionSection
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.GraphicsMode
import kotlin.concurrent.thread

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FeedbackEntryTest {

    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val config = FeedbackConfig(
        endpoint = "https://feedback.example.ch",
        appKey = "fbk_test",
        appVersion = "1.0",
        buildNumber = "1",
        environment = "test",
    )

    private fun feedbackSection(): DevExtensionSection? =
        AwlDebugExtensions.sections.value.singleOrNull { it.id == FEEDBACK_SECTION_ID }

    private fun showHost(config: FeedbackConfig?) {
        compose.setContent { FeedbackHost(config = config) { Box(Modifier.fillMaxSize().background(Color.White)) } }
        compose.waitForIdle()
    }

    @Test
    fun configuredHostOffersPanelEntryUntilItLeaves() {
        var showHost by mutableStateOf(true)
        compose.setContent {
            if (showHost) FeedbackHost(config = config.copy(triggers = setOf(DevTrigger.TripleTap))) { Box(Modifier.fillMaxSize()) }
        }
        compose.waitForIdle()

        val section = feedbackSection().shouldNotBeNull()
        section.order shouldBe FEEDBACK_SECTION_ORDER
        section.claimedTriggers shouldBe setOf(DevTrigger.TripleTap)
        val link = section.items.value.single().shouldBeInstanceOf<DevExtensionItem.Link>()
        link.text shouldBe "Send feedback"
        link.badge.shouldBeNull()

        showHost = false
        compose.waitForIdle()
        feedbackSection().shouldBeNull()
        ActiveFeedbackHost.current.shouldBeNull()
    }

    @Test
    fun hostWithoutConfigOffersNoEntry() {
        showHost(config = null)

        feedbackSection().shouldBeNull()
        ActiveFeedbackHost.current.shouldBeNull()
    }

    @Test
    fun panelEntryAndStartFromCodeStartTheShownHostOnTheMainThread() {
        showHost(config)
        val link = feedbackSection().shouldNotBeNull().items.value.single().shouldBeInstanceOf<DevExtensionItem.Link>()
        val startedOnMain = mutableListOf<Boolean>()
        val probe = ReportStarter { startedOnMain += Looper.myLooper() == Looper.getMainLooper() }
        ActiveFeedbackHost.set(probe)

        compose.runOnUiThread { link.onClick() }
        thread { AwlFeedback.start() }.join()
        shadowOf(Looper.getMainLooper()).idle()

        startedOnMain shouldBe listOf(true, true)
        ActiveFeedbackHost.clear(probe)
    }

    @Test
    @Suppress("DEPRECATION")
    fun shakeToReportMapsToTriggers() {
        val withoutShake = FeedbackConfig("https://e.example.ch", "k", "1", "1", "test", shakeToReport = false)

        withoutShake.triggers shouldBe setOf(DevTrigger.Screenshot)
        withoutShake.shakeToReport shouldBe false
        config.triggers shouldBe setOf(DevTrigger.Shake, DevTrigger.Screenshot)
    }
}
