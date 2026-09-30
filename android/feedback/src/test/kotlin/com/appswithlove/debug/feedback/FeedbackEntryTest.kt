package com.appswithlove.debug.feedback

import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.DevBridge
import com.appswithlove.debug.api.bridge.FeedbackEntry
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.GraphicsMode
import kotlin.concurrent.thread

@OptIn(AwlDebugInternalApi::class)
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

    @After
    fun tearDown() {
        DevBridge.feedbackLauncher.value = null
    }

    @Test
    fun configuredHostOffersEntryUntilItLeaves() {
        var showHost by mutableStateOf(true)
        compose.setContent {
            if (showHost) FeedbackHost(config = config.copy(triggers = setOf(DevTrigger.TripleTap))) { Box(Modifier.fillMaxSize()) }
        }
        compose.waitForIdle()

        DevBridge.feedbackLauncher.value.shouldNotBeNull().triggers shouldBe setOf(DevTrigger.TripleTap)

        showHost = false
        compose.waitForIdle()
        DevBridge.feedbackLauncher.value.shouldBeNull()
    }

    @Test
    fun hostWithoutConfigOffersNoEntry() {
        compose.setContent { FeedbackHost(config = null) { Box(Modifier.fillMaxSize()) } }
        compose.waitForIdle()

        DevBridge.feedbackLauncher.value.shouldBeNull()
    }

    @Test
    fun startFromCodeRunsEntryOnMainThread() {
        var startedOnMain: Boolean? = null
        DevBridge.feedbackLauncher.value = FeedbackEntry(emptySet(), MutableStateFlow(0)) {
            startedOnMain = Looper.myLooper() == Looper.getMainLooper()
        }

        thread { AwlFeedback.start() }.join()
        shadowOf(Looper.getMainLooper()).idle()

        startedOnMain shouldBe true
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
