package com.appswithlove.debug.extension

import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevNetworkRecord
import com.appswithlove.debug.ui.dev.log.DevHttpLogInterceptor
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.Log
import com.appswithlove.debug.ui.dev.log.LogCollector
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldEndWith
import io.kotest.matchers.string.shouldStartWith
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.io.IOException
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/** What [AwlDebugExtensions] hands to other libraries, fed by real requests and log calls. */
class ExtensionDataTest {

    private class Received(val record: DevNetworkRecord, val threadName: String)

    private val server = MockWebServer()
    private val received = LinkedBlockingQueue<Received>()
    private lateinit var listener: AutoCloseable

    @Before
    fun setUp() {
        // Added before this test creates its interceptor.
        listener = AwlDebugExtensions.addNetworkListener { received += Received(it, Thread.currentThread().name) }
        server.start()
    }

    @After
    fun tearDown() {
        listener.close()
        runCatching { server.shutdown() }
        LogCollector.logHistory.apply {
            selectedSeverityTags.value.forEach(::filterBySeverity)
            search("")
            clear()
        }
    }

    private fun client() = OkHttpClient.Builder()
        .addInterceptor(DevHttpLogInterceptor())
        .readTimeout(300, TimeUnit.MILLISECONDS)
        .build()

    private fun nextRecord(): Received = received.poll(5, TimeUnit.SECONDS).shouldNotBeNull()

    @Test
    fun networkListener_getsTheRedactedRequestOffTheCallingThread() {
        server.enqueue(MockResponse().setBody("""{"ok":true}""").addHeader("Content-Type", "application/json"))
        val request = Request.Builder()
            .url(server.url("/v1/login?user=someone"))
            .header("Authorization", "Bearer secret-token")
            .post("""{"name":"Test"}""".toRequestBody())
            .build()

        client().newCall(request).execute().use { it.body?.string() }

        val received = nextRecord()
        received.threadName shouldBe "awl-debug-extensions"
        with(received.record) {
            method shouldBe "POST"
            url shouldStartWith server.url("/v1/login").toString()
            status shouldBe 200
            errorCode shouldBe null
            requestHeaders shouldContain ("Authorization" to "[REDACTED]")
            responseBody?.text shouldBe """{"ok":true}"""
        }
        AwlDebugExtensions.networkSnapshot(maxEntries = 1).single().url shouldBe received.record.url
    }

    @Test
    fun networkListener_failedRequestsCarryAnErrorCode() {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        shouldThrow<IOException> { client().newCall(Request.Builder().url(server.url("/slow")).build()).execute() }
        with(nextRecord().record) {
            status shouldBe null
            errorCode shouldBe "timeout"
        }

        val port = server.port
        server.shutdown()
        shouldThrow<IOException> { client().newCall(Request.Builder().url("http://127.0.0.1:$port/down").build()).execute() }
        with(nextRecord().record) {
            status shouldBe null
            errorCode shouldBe "connection"
        }
    }

    @Test
    fun closedListener_getsNothing() {
        listener.close()
        server.enqueue(MockResponse())

        client().newCall(Request.Builder().url(server.url("/")).build()).execute().close()

        received.poll(500, TimeUnit.MILLISECONDS) shouldBe null
    }

    @Test
    fun logSnapshot_followsTheLogsModuleFilter() = runTest {
        val history = LogCollector.logHistory
        history.setTrackLogs(true)
        history.clear()
        val collector = LogCollector.devLogCollector
        collector.log(Log(DevLogSeverity.INFO, "checkout started", tag = "Cart"))
        collector.log(Log(DevLogSeverity.ERROR, "checkout failed with Authorization: Bearer abc", tag = "Cart", throwable = IllegalStateException("boom")))
        collector.log(Log(DevLogSeverity.WARN, "checkout slow"))
        collector.log(Log(DevLogSeverity.ERROR, "login failed"))
        history.filterBySeverity(DevLogSeverity.WARN)
        history.filterBySeverity(DevLogSeverity.ERROR)
        history.search("checkout")

        val snapshot = AwlDebugExtensions.logSnapshot(maxEntries = 10).shouldNotBeNull()

        snapshot.severityFilter shouldBe listOf("ERROR", "WARN")
        snapshot.searchQuery shouldBe "checkout"
        snapshot.records.map { it.severity } shouldBe listOf("ERROR", "WARN")
        with(snapshot.records.first()) {
            tag shouldBe "Cart"
            message shouldEndWith "[REDACTED]"
            throwable.shouldNotBeNull() shouldStartWith "java.lang.IllegalStateException: boom"
        }
        AwlDebugExtensions.logSnapshot(maxEntries = 1).shouldNotBeNull().records.single().message shouldBe "checkout slow"
    }
}
