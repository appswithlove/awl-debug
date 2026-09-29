package com.appswithlove.debug.feedback

import io.kotest.matchers.maps.shouldContainExactly
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartReader
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date

@RunWith(RobolectricTestRunner::class)
class FeedbackClientTest {

    private val server = MockWebServer()
    private val client = FeedbackClient()
    private val screenshot = FeedbackPart(name = "screenshot", fileName = "screenshot.jpg", mimeType = "image/jpeg", bytes = byteArrayOf(1, 2, 3))
    private val device = DeviceInfo(osVersion = "16", deviceModel = "Google Pixel 9", locale = "de-CH")
    private val extra = mapOf("screen" to "RecipeDetail", "userId" to "x".repeat(600))

    private lateinit var config: FeedbackConfig

    @Before
    fun setUp() {
        server.start()
        config = FeedbackConfig(
            endpoint = server.url("/").toString(),
            appKey = "app-key",
            appVersion = "1.0",
            buildNumber = "42",
            environment = "staging",
        )
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun sendsMultipartReportWithAppKey() = runTest {
        server.enqueue(MockResponse().setResponseCode(201).setBody("""{"taskId":"abc"}"""))
        val metadata = buildMetadataJson(config, device, extra, Date(0))

        val result = client.send(report(text = "Button is cut off", metadataJson = metadata))

        result shouldBe SendResult.Success(taskId = "abc")
        val request = server.takeRequest()
        request.path shouldBe "/v1/feedback"
        request.headers["X-App-Key"] shouldBe config.appKey
        request.headers["Idempotency-Key"] shouldBe IDEMPOTENCY_KEY
        val boundary = request.headers["Content-Type"]!!.toMediaType().parameter("boundary")!!
        val parts = MultipartReader(request.body, boundary).use { reader ->
            generateSequence { reader.nextPart() }.associate { part ->
                val disposition = part.headers["Content-Disposition"]!!
                val name = disposition.substringAfter("name=\"").substringBefore('"')
                name to (part.headers["Content-Type"] to part.body.readByteString())
            }
        }
        parts.getValue("text").second.utf8() shouldBe "Button is cut off"
        parts.getValue("metadata").second.utf8() shouldBe metadata
        parts.getValue("screenshot").first shouldBe screenshot.mimeType
        parts.getValue("screenshot").second.toByteArray().toList() shouldBe screenshot.bytes.toList()
    }

    @Test
    fun buildsMetadataWithCappedExtra() {
        val json = JSONObject(buildMetadataJson(config, device, extra, Date(0)))

        json.getString("platform") shouldBe "android"
        json.getString("osVersion") shouldBe device.osVersion
        json.getString("deviceModel") shouldBe device.deviceModel
        json.getString("appVersion") shouldBe config.appVersion
        json.getString("buildNumber") shouldBe config.buildNumber
        json.getString("environment") shouldBe config.environment
        json.getString("locale") shouldBe device.locale
        json.getString("screen") shouldBe extra.getValue("screen")
        json.getString("timestamp") shouldBe "1970-01-01T00:00:00.000Z"
        val sentExtra = json.getJSONObject("extra").let { obj -> obj.keys().asSequence().associateWith { obj.getString(it) } }
        sentExtra shouldContainExactly mapOf("screen" to "RecipeDetail", "userId" to "x".repeat(500))
    }

    @Test
    fun mapsRateLimitWithRetryAfter() = runTest {
        server.enqueue(MockResponse().setResponseCode(429).addHeader("Retry-After", "30").setBody("""{"error":"rate_limited"}"""))

        val result = client.send(report())

        result shouldBe SendResult.Failure(SendError.RateLimited(retryAfterSeconds = 30))
    }

    @Test
    fun mapsHttpStatusToError() {
        mapOf(
            400 to SendError.Invalid,
            401 to SendError.Unauthorized,
            413 to SendError.TooLarge,
            415 to SendError.UnsupportedMedia,
            502 to SendError.Server,
            503 to SendError.Server,
        ).forEach { (code, error) -> errorForStatus(code, retryAfter = null) shouldBe error }
    }

    @Test
    fun mapsUnreachableServiceToNetworkError() = runTest {
        val unreachable = config.copy(endpoint = server.url("/").toString())
        server.shutdown()

        val result = client.send(report(endpoint = unreachable.endpoint))

        result shouldBe SendResult.Failure(SendError.Network)
    }

    private fun report(text: String = "t", metadataJson: String = "{}", endpoint: String = config.endpoint) = FeedbackReport(
        idempotencyKey = IDEMPOTENCY_KEY,
        endpoint = endpoint,
        appKey = config.appKey,
        text = text,
        metadataJson = metadataJson,
        parts = listOf(screenshot),
    )

    private companion object {
        const val IDEMPOTENCY_KEY = "7f1d3a52-1c1e-4f7e-9a53-2b1f0c3d4e5f"
    }
}
