package com.appswithlove.debug.bridge

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.DevBridge
import com.appswithlove.debug.ui.dev.log.DevHttpLogInterceptor
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.Log
import com.appswithlove.debug.ui.dev.log.LogCollector
import com.appswithlove.debug.ui.dev.log.LogEntry
import com.appswithlove.debug.ui.dev.network.FIXTURE_TIME
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.networkEntry
import io.kotest.matchers.ints.shouldBeLessThanOrEqual
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
import java.util.TimeZone

@OptIn(AwlDebugInternalApi::class)
class LogsAttachmentTest {

    private val zurich = TimeZone.getTimeZone("Europe/Zurich")

    /** 2026-09-29T10:15:30.123+02:00 */
    private val localTime = FIXTURE_TIME - 2 * 60 * 60 * 1000

    @Test
    fun bodyMatchesGoldenFile() {
        val golden = javaClass.getResource("/golden/logs.txt")!!.readText()
        val failure = IllegalStateException("x").apply {
            stackTrace = arrayOf(StackTraceElement("com.example.Auth", "login", "Auth.kt", 42))
        }
        val logs = listOf(
            LogEntry(DevLogSeverity.ERROR, "failed", timestamp = localTime, tag = "Auth", throwable = failure),
            LogEntry(DevLogSeverity.WARN, "retrying", timestamp = localTime + 333),
        )
        val requests = listOf(
            networkEntry(
                method = "POST",
                url = "https://api.example.ch/v1/login",
                status = 401,
                durationMs = 342,
                requestHeaders = listOf("Content-Type" to "application/json", "Authorization" to "[REDACTED]"),
                responseHeaders = listOf("Content-Type" to "application/json"),
            ).copy(startedAtMillis = localTime - 1_122),
            networkEntry(
                url = "https://cdn.example.ch/img/42.jpg",
                status = 0,
                durationMs = 30_000,
                responseHeaders = emptyList(),
                responseBody = null,
                error = "java.net.SocketTimeoutException: timeout",
            ).copy(startedAtMillis = localTime - 623),
        )

        val body = logsAttachmentBody(
            logs = logs,
            filters = describeFilters(listOf(DevLogSeverity.WARN, DevLogSeverity.ERROR), "checkout"),
            requests = requests,
            maxBytes = DevBridge.LOGS_ATTACHMENT_BODY_MAX_BYTES,
            timeZone = zurich,
        )

        body shouldBe golden.substring(golden.indexOf("filters: "))
    }

    @Test
    fun leavesOutOldestEntriesWhenTooLarge() {
        val logs = (1..500).map { LogEntry(DevLogSeverity.INFO, "entry $it " + "x".repeat(1_000), timestamp = localTime + it) }

        val body = logsAttachmentBody(logs, "none", listOf(networkEntry()), maxBytes = 50_000, timeZone = zurich)

        body.toByteArray().size shouldBeLessThanOrEqual 50_000
        body shouldContain "older entries omitted"
        body shouldContain "| entry 500 "
        body shouldNotContain "| entry 1 "
        body shouldContain "## Network (1 of 50)\n"
        body shouldEndWith "https://api.example.com/v1/items?page=2\n    < content-type: application/json\n"
    }

    @Test
    fun attachmentFromRealCaptureHasNoCredentials() = runTest {
        val server = MockWebServer().apply { start() }
        server.enqueue(MockResponse().setResponseCode(200).addHeader("Set-Cookie", "session=cookie-secret").setBody("{}"))
        val client = OkHttpClient.Builder().addInterceptor(DevHttpLogInterceptor(DevNetworkConfig())).build()
        val request = Request.Builder().url(server.url("/v1/me?token=query-secret"))
            .header("Authorization", "Bearer header-secret")
            .build()
        client.newCall(request).execute().close()
        server.shutdown()
        LogCollector.devLogCollector.log(Log(DevLogSeverity.DEBUG, "Authorization: Bearer log-secret"))
        LogCollector.logHistory.search("")

        val body = DevBridge.feedbackAttachments!!.invoke()!!.toString(Charsets.UTF_8)

        body shouldStartWith "filters: none\n\n## Logs ("
        body shouldContain "> authorization: [REDACTED]"
        body shouldContain "Bearer [REDACTED]"
        listOf("header-secret", "cookie-secret", "query-secret", "log-secret").forEach { body shouldNotContain it }
        NetworkCollector.store.clear()
        LogCollector.logHistory.clear()
    }
}
