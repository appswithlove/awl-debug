package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.ui.dev.network.BodyCapture
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.NetworkLogStore
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import okio.BufferedSink
import org.junit.After
import org.junit.Test
import java.io.IOException
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** The capture must never change what the app sends or receives, and never fail the app's call. */
class DevHttpLogInterceptorRobustnessTest {

    private val server = MockWebServer().apply { start() }
    private val store = NetworkLogStore()
    private val collector = object : DevLogCollector {
        override fun setTrackLogs(track: Boolean) = Unit
        override fun log(log: Log) = Unit
        override fun setMaxSize(size: Int) = Unit
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun client(executor: Executor = Executor(Runnable::run), config: DevNetworkConfig = DevNetworkConfig()) =
        OkHttpClient.Builder().addInterceptor(DevHttpLogInterceptor(config, store, collector, executor)).build()

    private fun entry(): NetworkEntry = store.entries.value.single()

    @Test
    fun customRequestBody_isWrittenOnlyOnce() {
        server.enqueue(MockResponse())
        var writes = 0
        val body = object : RequestBody() {
            override fun contentType() = "application/json".toMediaType()
            override fun contentLength() = 2L
            override fun writeTo(sink: BufferedSink) {
                writes++
                sink.writeUtf8("{}")
            }
        }

        client().newCall(Request.Builder().url(server.url("/")).post(body).build()).execute().close()

        writes shouldBe 1
        server.takeRequest().body.readUtf8() shouldBe "{}"
        entry().requestBody!!.text shouldBe BodyCapture.CUSTOM_BODY
    }

    @Test
    fun parserStoppingBeforeTheChunkedEnd_isStillCaptured() {
        val json = """{"idToken":"t","ok":true}"""
        server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setChunkedBody(json, 8))

        client().newCall(Request.Builder().url(server.url("/")).build()).execute().use { response ->
            response.body!!.source().readUtf8(json.length.toLong()) shouldBe json
        }

        entry().responseBody!!.text shouldBe """{"idToken":"[REDACTED]","ok":true}"""
    }

    @Test
    fun bodyFailingMidway_isRecordedWithTheError() {
        server.enqueue(
            MockResponse().setHeader("Content-Type", "text/plain").setBody("x".repeat(64 * 1024))
                .setSocketPolicy(SocketPolicy.DISCONNECT_DURING_RESPONSE_BODY)
        )

        shouldThrow<IOException> {
            client().newCall(Request.Builder().url(server.url("/")).build()).execute().use { it.body!!.string() }
        }

        entry().error shouldNotBe null
        entry().responseBody!!.text shouldBe BodyCapture.INCOMPLETE
    }

    @Test
    fun fullCaptureQueue_neverFailsTheCall() {
        server.enqueue(MockResponse().setBody("ok"))
        val rejecting = Executor { throw RejectedExecutionException() }

        client(rejecting).newCall(Request.Builder().url(server.url("/")).build()).execute().use {
            it.body!!.string() shouldBe "ok"
        }

        store.entries.value shouldBe emptyList()
    }

    @Test
    fun bodiesBeyondTheMemoryBudget_areLeftOut() {
        val body = "a".repeat(1_000_000)
        repeat(20) { server.enqueue(MockResponse().setHeader("Content-Type", "text/plain").setBody(body)) }
        val waiting = mutableListOf<Runnable>()
        val client = client(executor = Executor { waiting += it }, config = DevNetworkConfig(maxBodyBytes = 2_000_000))

        repeat(20) {
            client.newCall(Request.Builder().url(server.url("/$it")).build()).execute().use { it.body!!.string() }
        }
        waiting.forEach(Runnable::run)

        val bodies = store.entries.value.map { it.responseBody!!.text }
        bodies.count { it == body } shouldBe 16
        bodies.count { it == "(not captured, too many requests waiting)" } shouldBe 4
    }

    @Test
    fun textBodies_areRedacted() {
        server.enqueue(MockResponse().setHeader("Content-Type", "text/plain").setBody("""{"password":"p","name":"n"}"""))
        server.enqueue(
            MockResponse().setHeader("Content-Type", "application/soap+xml")
                .setBody("""<s:Envelope><ns:Password>p</ns:Password><user token='t'/></s:Envelope>""")
        )
        val client = client()
        val request = Request.Builder().url(server.url("/")).post("Authorization: Bearer abc.def".toRequestBody("text/plain".toMediaType())).build()

        client.newCall(request).execute().use { it.body!!.string() }
        client.newCall(Request.Builder().url(server.url("/")).build()).execute().use { it.body!!.string() }

        val (first, second) = store.entries.value
        first.requestBody!!.text shouldBe "Authorization: Bearer [REDACTED]"
        first.responseBody!!.text shouldBe """{"password":"[REDACTED]","name":"n"}"""
        second.responseBody!!.text shouldBe """<s:Envelope><ns:Password>[REDACTED]</ns:Password><user token='[REDACTED]'/></s:Envelope>"""
    }
}
