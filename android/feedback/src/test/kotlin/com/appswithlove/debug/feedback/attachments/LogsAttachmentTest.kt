package com.appswithlove.debug.feedback.attachments

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.api.extension.DevLogRecord
import com.appswithlove.debug.api.extension.DevLogSnapshot
import com.appswithlove.debug.api.extension.DevNetworkBody
import com.appswithlove.debug.api.extension.DevNetworkRecord
import com.appswithlove.debug.feedback.AwlDistribution
import com.appswithlove.debug.feedback.DeviceInfo
import com.appswithlove.debug.feedback.FeedbackConfig
import com.appswithlove.debug.ui.dev.log.DevHttpLogInterceptor
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.Log
import com.appswithlove.debug.ui.dev.log.LogCollector
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldEndWith
import io.kotest.matchers.string.shouldNotContain
import io.kotest.matchers.string.shouldStartWith
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Test
import java.util.Date
import java.util.TimeZone

class LogsAttachmentTest {

    private val golden = javaClass.getResource("/golden/logs.txt")!!.readText()
    private val zurich = TimeZone.getTimeZone("Europe/Zurich")
    private val config = FeedbackConfig(
        endpoint = "https://feedback.example.ch",
        appKey = "app-key",
        appVersion = "2.3.0",
        buildNumber = "1024",
        environment = "staging",
        distribution = AwlDistribution.Internal,
    )
    private val device = DeviceInfo(osVersion = "16", deviceModel = "Google Pixel 9", locale = "de-CH")

    /** 2026-09-29T10:15:31.000+02:00 */
    private val generatedAt = Date(1_790_669_731_000L)

    /** 2026-09-29T10:15:30.123+02:00 */
    private val localTime = 1_790_669_730_123L

    private fun request(
        startedAtMillis: Long = localTime,
        method: String = "GET",
        url: String = "https://api.example.com/v1/items?page=2",
        status: Int? = 200,
        durationMs: Long = 120,
        requestHeaders: List<Pair<String, String>> = emptyList(),
        responseHeaders: List<Pair<String, String>> = listOf("Content-Type" to "application/json"),
        errorCode: String? = null,
    ) = DevNetworkRecord(
        startedAtMillis = startedAtMillis,
        method = method,
        url = url,
        status = status,
        durationMs = durationMs,
        requestHeaders = requestHeaders,
        responseHeaders = responseHeaders,
        requestBody = null,
        responseBody = DevNetworkBody("{}", "application/json", truncated = false, originalBytes = 2, isContent = true),
        errorCode = errorCode,
        requestBytes = null,
        responseBytes = 2,
    )

    @Test
    fun fileMatchesGoldenFile() = runTest {
        val failure = IllegalStateException("x").apply {
            stackTrace = arrayOf(StackTraceElement("com.example.Auth", "login", "Auth.kt", 42))
        }
        val logs = DevLogSnapshot(
            records = listOf(
                DevLogRecord(localTime, "ERROR", "Auth", "failed", failure.stackTraceToString()),
                DevLogRecord(localTime + 333, "WARN", null, "retrying", null),
            ),
            severityFilter = listOf("ERROR", "WARN"),
            searchQuery = "checkout",
        )
        val requests = listOf(
            request(
                startedAtMillis = localTime - 1_122,
                method = "POST",
                url = "https://api.example.ch/v1/login",
                status = 401,
                durationMs = 342,
                requestHeaders = listOf("Content-Type" to "application/json", "Authorization" to "[REDACTED]"),
            ),
            request(
                startedAtMillis = localTime - 623,
                url = "https://cdn.example.ch/img/42.jpg",
                status = null,
                durationMs = 30_000,
                responseHeaders = emptyList(),
                errorCode = "timeout",
            ),
        )

        val file = captureLogsAttachment(config, device, generatedAt, zurich, logs = { logs }, requests = { requests })

        file.shouldNotBeNull().toString(Charsets.UTF_8) shouldBe golden
    }

    @Test
    fun leavesOutOldestEntriesWhenTooLarge() {
        val logs = (1..500).map { DevLogRecord(localTime + it, "INFO", null, "entry $it " + "x".repeat(1_000), null) }

        val body = logsAttachmentBody(logs, "none", listOf(request()), maxBytes = 50_000, timeZone = zurich)

        body.toByteArray().size shouldBeLessThanOrEqual 50_000
        body shouldContain "older entries omitted"
        body shouldContain "| entry 500 "
        body shouldNotContain "| entry 1 "
        body shouldContain "## Network (1 of 50)\n"
        body shouldEndWith "https://api.example.com/v1/items?page=2\n    < content-type: application/json\n"
    }

    @Test
    fun largeLogsStayWithinTheServiceLimit() = runTest {
        val logs = DevLogSnapshot((1..500).map { DevLogRecord(localTime + it, "INFO", null, "y".repeat(4_000), null) }, emptyList(), "")

        val file = captureLogsAttachment(config, device, generatedAt, zurich, logs = { logs }, requests = { emptyList() })

        file.shouldNotBeNull().size shouldBeLessThanOrEqual LOGS_MAX_BYTES
        file.toString(Charsets.UTF_8) shouldContain "older entries omitted"
    }

    @Test
    fun nothingWithoutDebugPanel() = runTest {
        captureLogsAttachment(config, device, generatedAt, logs = { null }) shouldBe null
    }

    @Test
    fun realCaptureOfTheDebugPanelHasNoCredentials() = runTest {
        val server = MockWebServer().apply { start() }
        server.enqueue(MockResponse().setResponseCode(200).addHeader("Set-Cookie", "session=cookie-secret").setBody("{}"))
        val client = OkHttpClient.Builder().addInterceptor(DevHttpLogInterceptor(DevNetworkConfig())).build()
        val request = Request.Builder().url(server.url("/v1/me?token=query-secret"))
            .header("Authorization", "Bearer header-secret")
            .build()
        client.newCall(request).execute().close()
        server.shutdown()
        LogCollector.devLogCollector.log(Log(DevLogSeverity.DEBUG, "Authorization: Bearer log-secret"))

        val text = captureLogsAttachment(config, device, generatedAt).shouldNotBeNull().toString(Charsets.UTF_8)

        text shouldStartWith "# AWL Debug logs\n"
        text shouldContain "filters: none\n\n## Logs ("
        text shouldContain "> authorization: [REDACTED]"
        text shouldContain "Bearer [REDACTED]"
        listOf("header-secret", "cookie-secret", "query-secret", "log-secret").forEach { text shouldNotContain it }
    }
}
