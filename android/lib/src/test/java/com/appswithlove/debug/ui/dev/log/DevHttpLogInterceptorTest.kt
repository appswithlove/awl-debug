package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.NetworkLogStore
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldEndWith
import io.kotest.matchers.string.shouldStartWith
import okhttp3.FormBody
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import okio.BufferedSink
import okio.GzipSink
import okio.buffer
import org.junit.After
import org.junit.Test
import java.io.IOException
import java.util.concurrent.TimeUnit

class DevHttpLogInterceptorTest {

    private class RecordingCollector : DevLogCollector {
        val logs = mutableListOf<Log>()
        override fun setTrackLogs(track: Boolean) = Unit
        override fun log(log: Log) {
            logs += log
        }
        override fun setMaxSize(size: Int) = Unit
    }

    private val server = MockWebServer().apply { start() }
    private val store = NetworkLogStore()
    private val collector = RecordingCollector()
    private val json = "application/json".toMediaType()

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun client(config: DevNetworkConfig = DevNetworkConfig()) = OkHttpClient.Builder()
        .addInterceptor(DevHttpLogInterceptor(config, store, collector))
        .build()

    private fun execute(request: Request, config: DevNetworkConfig = DevNetworkConfig()): NetworkEntry {
        client(config).newCall(request).execute().use { it.body?.string() }
        return store.entries.value.last()
    }

    @Test
    fun intercept_sensitiveHeaders_areRedacted() {
        server.enqueue(MockResponse().setBody("ok").addHeader("Set-Cookie", "c=d"))
        val request = Request.Builder()
            .url(server.url("/"))
            .header("Authorization", "Bearer x")
            .header("Cookie", "a=b")
            .header("x-api-key", "123")
            .header("X-Visible", "visible")
            .build()

        val entry = execute(request, DevNetworkConfig(redactHeaders = setOf("X-Api-Key")))

        entry.requestHeaders shouldContainExactly listOf(
            "Authorization" to "[REDACTED]",
            "Cookie" to "[REDACTED]",
            "x-api-key" to "[REDACTED]",
            "X-Visible" to "visible",
        )
        entry.responseHeaders shouldContain ("Set-Cookie" to "[REDACTED]")
        entry.redactedCount shouldBe 4
    }

    @Test
    fun intercept_urlUserinfoAndQueryParams_areRedacted() {
        server.enqueue(MockResponse())
        val url = server.url("/items").newBuilder()
            .username("user").password("pass")
            .addQueryParameter("token", "abc")
            .addQueryParameter("page", "2")
            .build()

        val entry = execute(Request.Builder().url(url).build())

        entry.url shouldBe "http://[REDACTED]@${server.hostName}:${server.port}/items?token=[REDACTED]&page=2"
        server.takeRequest().requestUrl!!.queryParameter("token") shouldBe "abc"
    }

    @Test
    fun intercept_nestedJsonFields_areRedactedAtAnyDepth() {
        server.enqueue(
            MockResponse()
                .setHeader("Content-Type", "application/json")
                .setBody("""{"user":{"password":"p","items":[{"access_token":"t","id":1}]}}""")
        )

        val entry = execute(Request.Builder().url(server.url("/")).build())

        entry.responseBody!!.text shouldBe
            """{"user":{"password":"[REDACTED]","items":[{"access_token":"[REDACTED]","id":1}]}}"""
        entry.redactedCount shouldBe 2
    }

    @Test
    fun intercept_formBody_isRedacted() {
        server.enqueue(MockResponse())
        val form = FormBody.Builder().add("username", "a").add("password", "p").build()

        val entry = execute(Request.Builder().url(server.url("/")).post(form).build())

        entry.requestBody!!.text shouldBe "username=a&password=[REDACTED]"
        server.takeRequest().body.readUtf8() shouldBe "username=a&password=p"
    }

    @Test
    fun intercept_largeJsonBody_isRedactedThenTruncated() {
        val prefix = """{"password":"p","data":""""
        val suffix = "\"}"
        val body = prefix + "a".repeat(300 * 1024 - prefix.length - suffix.length) + suffix
        server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setBody(body))

        val entry = execute(Request.Builder().url(server.url("/")).build())

        val captured = entry.responseBody!!
        captured.truncated shouldBe true
        captured.originalBytes shouldBe 307_200L
        captured.text.length shouldBe 256 * 1024
        captured.text shouldStartWith """{"password":"[REDACTED]""""
    }

    @Test
    fun intercept_unparsableJsonAndBinary_arePlaceholders() {
        server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setBody("{broken"))
        server.enqueue(MockResponse().setHeader("Content-Type", "image/png").setBody("PNG-bytes"))

        val unparsable = execute(Request.Builder().url(server.url("/a")).build())
        val binary = execute(Request.Builder().url(server.url("/b")).build())

        unparsable.responseBody!!.text shouldBe "(unparsable JSON, not shown)"
        binary.responseBody!!.text shouldBe "(binary, 9 bytes)"
    }

    @Test
    fun intercept_oneShotRequestBody_isNotReadAndReachesServerIntact() {
        server.enqueue(MockResponse())
        var writeCount = 0
        val oneShotBody = object : RequestBody() {
            override fun contentType() = "text/plain".toMediaType()
            override fun isOneShot() = true
            override fun writeTo(sink: BufferedSink) {
                writeCount++
                sink.writeUtf8("upload-payload")
            }
        }

        val entry = execute(Request.Builder().url(server.url("/")).post(oneShotBody).build())

        writeCount shouldBe 1
        server.takeRequest().body.readUtf8() shouldBe "upload-payload"
        entry.requestBody!!.text shouldBe "(one-shot body, not captured)"
    }

    @Test
    fun intercept_eventStream_isNotPeekedAndDoesNotBlock() {
        server.enqueue(
            MockResponse()
                .setHeader("Content-Type", "text/event-stream")
                .setBody("data: first\n\n" + "data: more\n\n".repeat(100))
                .throttleBody(16, 1, TimeUnit.SECONDS)
        )

        val startedAt = System.nanoTime()
        client().newCall(Request.Builder().url(server.url("/events")).build()).execute().use { response ->
            response.body!!.source().readUtf8Line() shouldBe "data: first"
        }
        val elapsedMs = ((System.nanoTime() - startedAt) / 1_000_000).toInt()

        elapsedMs shouldBeLessThan 3_000
        store.entries.value.single().responseBody!!.text shouldBe "(stream, not captured)"
    }

    @Test
    fun intercept_ndjsonAndConfiguredStreamTypes_areNotPeeked() {
        server.enqueue(MockResponse().setHeader("Content-Type", "application/x-ndjson").setBody("{\"a\":1}\n"))
        server.enqueue(MockResponse().setHeader("Content-Type", "Application/Custom-Stream").setBody("chunk"))
        val config = DevNetworkConfig(streamContentTypes = setOf("application/custom-stream"))

        val ndjson = execute(Request.Builder().url(server.url("/ndjson")).build(), config)
        val custom = execute(Request.Builder().url(server.url("/custom")).build(), config)

        ndjson.responseBody!!.text shouldBe "(stream, not captured)"
        custom.responseBody!!.text shouldBe "(stream, not captured)"
    }

    @Test
    fun intercept_multipart_redactsFieldsAndSummarizesFiles() {
        server.enqueue(MockResponse())
        val multipart = MultipartBody.Builder("boundary")
            .setType(MultipartBody.FORM)
            .addFormDataPart("password", "p")
            .addFormDataPart("note", "hello")
            .addFormDataPart("avatar", "me.png", "PNG".toRequestBody("image/png".toMediaType()))
            .build()

        val entry = execute(Request.Builder().url(server.url("/")).post(multipart).build())

        val lines = entry.requestBody!!.text.lines()
        lines shouldContain "[REDACTED]"
        lines shouldContain "hello"
        lines shouldContain "(file me.png, 3 bytes)"
    }

    @Test
    fun intercept_captureBodiesDisabled_storesNoBodyContent() {
        server.enqueue(MockResponse().setBody("not wanted"))

        val entry = execute(
            Request.Builder().url(server.url("/")).post("x".toRequestBody(json)).build(),
            DevNetworkConfig(captureBodies = false),
        )

        entry.requestBody!!.text shouldBe "(not captured)"
        entry.responseBody!!.text shouldBe "(not captured)"
    }

    @Test
    fun intercept_failedRequest_isRecordedWithStatusZero() {
        val url = server.url("/")
        server.shutdown()

        shouldThrow<IOException> {
            client().newCall(Request.Builder().url(url).build()).execute()
        }

        val entry = store.entries.value.single()
        entry.isFailed shouldBe true
        (entry.error != null) shouldBe true
        collector.logs.single().severity shouldBe DevLogSeverity.ERROR
    }

    @Test
    fun intercept_writesShortSummaryToLogs() {
        server.enqueue(MockResponse().setResponseCode(404))

        execute(Request.Builder().url(server.url("/missing?token=abc")).build())

        val log = collector.logs.single()
        log.tag shouldBe "HTTP"
        log.severity shouldBe DevLogSeverity.WARN
        log.message shouldStartWith "GET 404 "
        log.message shouldEndWith "ms http://${server.hostName}:${server.port}/missing?token=[REDACTED]"
    }

    @Test
    fun intercept_asNetworkInterceptor_decodesGzipBody() {
        val gzipped = Buffer().also { buffer ->
            GzipSink(buffer).buffer().use { it.writeUtf8("""{"idToken":"t","ok":true}""") }
        }
        server.enqueue(
            MockResponse()
                .setHeader("Content-Type", "application/json")
                .setHeader("Content-Encoding", "gzip")
                .setBody(gzipped)
        )
        val client = OkHttpClient.Builder()
            .addNetworkInterceptor(DevHttpLogInterceptor(DevNetworkConfig(), store, collector))
            .build()

        client.newCall(Request.Builder().url(server.url("/")).build()).execute().use {
            it.body!!.string() shouldBe """{"idToken":"t","ok":true}"""
        }

        store.entries.value.single().responseBody!!.text shouldBe """{"idToken":"[REDACTED]","ok":true}"""
    }
}
