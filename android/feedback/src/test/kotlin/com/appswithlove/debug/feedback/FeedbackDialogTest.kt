package com.appswithlove.debug.feedback

import androidx.activity.ComponentActivity
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import com.appswithlove.debug.feedback.queue.FeedbackQueue
import io.kotest.matchers.shouldBe
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FeedbackDialogTest {

    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val server = MockWebServer()
    private val draft = FeedbackDraft(screenshot = ImageBitmap(40, 80), metadataJson = "{}")
    private var sent = false
    private var queued = false
    private lateinit var queue: FeedbackQueue

    @Before
    fun setUp() {
        server.start()
        queue = FeedbackQueue(File(RuntimeEnvironment.getApplication().cacheDir, "feedback-queue-test").apply { deleteRecursively() })
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun reportsSentAfterServiceAccepted() {
        server.enqueue(MockResponse().setResponseCode(201).setBody("""{"taskId":"abc"}"""))
        openDialog()

        sendReport()

        compose.waitUntil(timeoutMillis = 5_000) { sent }
        server.requestCount shouldBe 1
    }

    @Test
    fun reportsQueuedWhenServiceIsUnavailable() {
        server.enqueue(MockResponse().setResponseCode(503))
        openDialog()

        sendReport()

        compose.waitUntil(timeoutMillis = 5_000) { queued }
        sent shouldBe false
        queue.pendingCount.value shouldBe 1
    }

    @Test
    fun staysOpenWithErrorWhenServiceRejectsKey() {
        server.enqueue(MockResponse().setResponseCode(401))
        openDialog()

        sendReport()

        val error = compose.activity.getString(R.string.feedback_error_unauthorized)
        compose.waitUntil(timeoutMillis = 5_000) { compose.onAllNodes(hasText(error)).fetchSemanticsNodes().isNotEmpty() }
        sent shouldBe false
        queued shouldBe false
    }

    private fun openDialog() {
        val config = FeedbackConfig(
            endpoint = server.url("/").toString(),
            appKey = "app-key",
            appVersion = "1.0",
            buildNumber = "1",
            environment = "test",
            shakeToReport = false,
        )
        compose.setContent {
            FeedbackDialog(config = config, draft = draft, onCancel = {}, onSent = { sent = true }, onQueued = { queued = true }, queue = queue)
        }
    }

    private fun sendReport() {
        compose.onNode(hasSetTextAction()).performTextInput("Button is cut off")
        compose.onNodeWithText(compose.activity.getString(R.string.feedback_send)).performClick()
    }
}
