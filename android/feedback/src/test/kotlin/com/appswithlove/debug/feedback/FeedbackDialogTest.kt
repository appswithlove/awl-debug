package com.appswithlove.debug.feedback

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import androidx.activity.ComponentActivity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.percentOffset
import androidx.compose.ui.test.swipe
import com.appswithlove.debug.feedback.queue.FeedbackQueue
import io.kotest.matchers.shouldBe
import okhttp3.mockwebserver.MockResponse
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartReader
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FeedbackDialogTest {

    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val server = MockWebServer()
    private var draft by mutableStateOf(newDraft())
    private var sent = false
    private var queued = false
    private lateinit var queue: FeedbackQueue
    private lateinit var reporterStore: ReporterStore

    @Before
    fun setUp() {
        server.start()
        val app = RuntimeEnvironment.getApplication()
        queue = FeedbackQueue(File(app.cacheDir, "feedback-queue-test").apply { deleteRecursively() })
        reporterStore = ReporterStore(app.getSharedPreferences("reporter-test", Context.MODE_PRIVATE).apply { edit().clear().commit() })
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
        server.takeRequest().metadata().getJSONObject("reporter").getString("name") shouldBe "Test User"
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

    @Test
    fun asksForNameOnFirstReportAndShowsSentAsAfterwards() {
        server.enqueue(MockResponse().setResponseCode(201))
        openDialog(reporter = null)
        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_text_label))).performTextInput("Button is cut off")
        compose.onNodeWithText(string(R.string.feedback_send)).assertIsNotEnabled()

        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_reporter_prompt))).performTextInput("Sam Tester")
        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_reporter_email))).performTextInput("sam@example.ch")
        compose.onNodeWithText(string(R.string.feedback_send)).performClick()

        compose.waitUntil(timeoutMillis = 5_000) { sent }
        server.takeRequest().metadata().getJSONObject("reporter").toString() shouldBe
            JSONObject().put("name", "Sam Tester").put("email", "sam@example.ch").toString()

        draft = newDraft()
        compose.onNodeWithText(compose.activity.getString(R.string.feedback_reporter_sent_as, "Sam Tester")).assertIsDisplayed()
        compose.onAllNodes(hasText(string(R.string.feedback_reporter_prompt))).fetchSemanticsNodes().size shouldBe 0
        compose.onNodeWithText(string(R.string.feedback_reporter_change)).performClick()
        compose.onNode(hasSetTextAction() and hasText("Sam Tester")).assertIsDisplayed()
    }

    @Test
    fun blocksSendingWithInvalidEmail() {
        openDialog(reporter = null)
        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_text_label))).performTextInput("Button is cut off")
        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_reporter_prompt))).performTextInput("Sam")
        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_reporter_email))).performTextInput("sam@")

        compose.onNodeWithText(string(R.string.feedback_send)).assertIsNotEnabled()
    }

    @Test
    fun sendsRedactedAreaBlack() {
        server.enqueue(MockResponse().setResponseCode(201))
        openDialog()
        compose.onNodeWithContentDescription(string(R.string.feedback_tool_redact)).performClick()
        compose.onNodeWithContentDescription(string(R.string.feedback_markup_canvas)).performTouchInput {
            swipe(start = percentOffset(0.1f, 0.1f), end = percentOffset(0.9f, 0.9f))
        }

        sendReport()

        compose.waitUntil(timeoutMillis = 5_000) { sent }
        val jpeg = server.takeRequest().part("screenshot")
        val uploaded = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
        val center = uploaded.getPixel(uploaded.width / 2, uploaded.height / 2)
        (Color.red(center) + Color.green(center) + Color.blue(center) <= 36) shouldBe true
        uploaded.getPixel(0, 0) shouldBe Color.WHITE
    }

    @Test
    @Config(qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun largeFontKeepsAllToolsAndStacksReporterFields() {
        openDialog(reporter = null)

        // The toolbar switches to two columns instead of hiding undo and clear below the fold.
        compose.onNodeWithContentDescription(string(R.string.feedback_undo)).assertIsDisplayed()
        compose.onNodeWithContentDescription(string(R.string.feedback_clear)).assertIsDisplayed()
        val name = compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_reporter_prompt))).fetchSemanticsNode().boundsInRoot
        val email = compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_reporter_email))).fetchSemanticsNode().boundsInRoot
        (email.top >= name.bottom) shouldBe true
    }

    private fun openDialog(reporter: FeedbackReporter? = FeedbackReporter(name = "Test User")) {
        val config = FeedbackConfig(
            endpoint = server.url("/").toString(),
            appKey = "app-key",
            appVersion = "1.0",
            buildNumber = "1",
            environment = "test",
            shakeToReport = false,
            reporter = reporter,
        )
        compose.setContent {
            FeedbackDialog(
                config = config,
                draft = draft,
                onCancel = {},
                onSent = { sent = true },
                onQueued = { queued = true },
                queue = queue,
                reporterStore = reporterStore,
            )
        }
    }

    private fun sendReport() {
        compose.onNode(hasSetTextAction() and hasText(string(R.string.feedback_text_label))).performTextInput("Button is cut off")
        compose.onNodeWithText(string(R.string.feedback_send)).performClick()
    }

    private fun string(id: Int): String = compose.activity.getString(id)

    private fun newDraft() = FeedbackDraft(screenshot = ImageBitmap(40, 80), metadataJson = { reporter -> metadataFor(reporter) })

    private fun metadataFor(reporter: FeedbackReporter?): String = JSONObject().apply {
        reporter?.let { put("reporter", JSONObject().put("name", it.name).putOpt("email", it.email)) }
    }.toString()

    private fun RecordedRequest.metadata(): JSONObject = JSONObject(part("metadata").decodeToString())

    private fun RecordedRequest.part(name: String): ByteArray {
        val boundary = requireNotNull(headers["Content-Type"]?.toMediaType()?.parameter("boundary"))
        MultipartReader(body, boundary).use { reader ->
            while (true) {
                val part = reader.nextPart() ?: error("No part $name")
                if (part.headers["Content-Disposition"]?.contains("name=\"$name\"") == true) return part.body.readByteArray()
            }
        }
    }
}
