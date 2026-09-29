package com.appswithlove.debug.ui.dev.log

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.BufferedSink
import org.junit.After
import org.junit.Test

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
    private val collector = RecordingCollector()

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun String.loggedBody() = substringAfter("Body: ").substringBefore("\n(truncated")

    private fun client(redactHeaders: Set<String> = emptySet()) = OkHttpClient.Builder()
        .addInterceptor(DevHttpLogInterceptor(collector, redactHeaders))
        .build()

    @Test
    fun intercept_sensitiveHeaders_areRedactedInRequestAndResponse() {
        server.enqueue(MockResponse().setBody("ok").addHeader("Set-Cookie", "c=d"))
        val request = Request.Builder()
            .url(server.url("/"))
            .header("Authorization", "Bearer abc.def")
            .header("Proxy-Authorization", "Basic cHJveHk=")
            .header("Cookie", "a=b")
            .header("x-api-key", "123")
            .header("X-Visible", "visible-value")
            .build()

        client(redactHeaders = setOf("X-Api-Key")).newCall(request).execute().close()

        val logged = collector.logs.joinToString("\n") { it.message }
        logged shouldContain "Authorization: [REDACTED]"
        logged shouldContain "Proxy-Authorization: [REDACTED]"
        logged shouldContain "Cookie: [REDACTED]"
        logged shouldContain "Set-Cookie: [REDACTED]"
        logged shouldContain "x-api-key: [REDACTED]"
        logged shouldContain "X-Visible: visible-value"
        listOf("abc.def", "cHJveHk=", "a=b", "c=d", "123").forEach { logged shouldNotContain it }
    }

    @Test
    fun intercept_largeResponseBody_isTruncatedInLogButDeliveredInFull() {
        val body = "a".repeat(300 * 1024)
        server.enqueue(MockResponse().setBody(body))

        val received = client().newCall(Request.Builder().url(server.url("/")).build())
            .execute().use { it.body!!.string() }

        received.length shouldBe body.length
        val responseLog = collector.logs.last().message
        responseLog shouldContain "(truncated, ${300 * 1024} bytes total)"
        responseLog.loggedBody().length shouldBe DevHttpLogInterceptor.DEFAULT_MAX_BODY_BYTES.toInt()
    }

    @Test
    fun intercept_largeRequestBody_isTruncatedInLog() {
        server.enqueue(MockResponse())
        val body = "b".repeat(300 * 1024).toRequestBody("text/plain".toMediaType())

        client().newCall(Request.Builder().url(server.url("/")).post(body).build()).execute().close()

        server.takeRequest().bodySize shouldBe 300L * 1024
        val requestLog = collector.logs.first().message
        requestLog shouldContain "(truncated, ${300 * 1024} bytes total)"
        requestLog.loggedBody().length shouldBe DevHttpLogInterceptor.DEFAULT_MAX_BODY_BYTES.toInt()
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

        client().newCall(Request.Builder().url(server.url("/")).post(oneShotBody).build())
            .execute().close()

        writeCount shouldBe 1
        server.takeRequest().body.readUtf8() shouldBe "upload-payload"
        collector.logs.first().message shouldContain "(one-shot body, not captured)"
    }
}
