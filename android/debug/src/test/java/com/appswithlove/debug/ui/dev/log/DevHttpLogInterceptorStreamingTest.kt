package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.NetworkLogStore
import io.kotest.matchers.ints.shouldBeLessThan
import io.kotest.matchers.shouldBe
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Test
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/** WebSockets and streamed bodies must reach the app as without the interceptor. */
class DevHttpLogInterceptorStreamingTest {

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

    private fun interceptor() = DevHttpLogInterceptor(DevNetworkConfig(), store, collector, Runnable::run)

    private fun awaitEntry(): NetworkEntry {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (store.entries.value.isEmpty() && System.nanoTime() < deadline) Thread.sleep(10)
        return store.entries.value.single()
    }

    private fun assertWebSocketEchoes(client: OkHttpClient) {
        server.enqueue(MockResponse().withWebSocketUpgrade(object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) {
                webSocket.send(text)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(code, null)
            }
        }))
        val messages = LinkedBlockingQueue<String>()
        val webSocket = client.newWebSocket(Request.Builder().url(server.url("/sync")).build(), object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) {
                messages += text
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                messages += "closed"
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                messages += "failure: $t"
            }
        })

        webSocket.send("first")
        messages.poll(5, TimeUnit.SECONDS) shouldBe "first"
        webSocket.send("second")
        messages.poll(5, TimeUnit.SECONDS) shouldBe "second"
        webSocket.close(1000, null)
        messages.poll(5, TimeUnit.SECONDS) shouldBe "closed"
    }

    @Test
    fun webSocket_asApplicationInterceptor_staysOpenAndIsRecorded() {
        assertWebSocketEchoes(OkHttpClient.Builder().addInterceptor(interceptor()).build())

        val entry = awaitEntry()
        entry.status shouldBe 101
        entry.responseBody shouldBe null
    }

    /** OkHttp does not call network interceptors for WebSockets. */
    @Test
    fun webSocket_asNetworkInterceptor_staysOpenAndIsNotRecorded() {
        assertWebSocketEchoes(OkHttpClient.Builder().addNetworkInterceptor(interceptor()).build())

        store.entries.value shouldBe emptyList()
    }

    /** A text body without a declared stream type, sent chunk by chunk: the first line must not wait for the rest. */
    @Test
    fun chunkedJsonStream_reachesTheAppChunkByChunk() {
        val lines = List(20) { """{"line":$it,"token":"t"}""" }
        server.enqueue(
            MockResponse()
                .setHeader("Content-Type", "application/json")
                .setChunkedBody(lines.joinToString("\n", postfix = "\n"), 16)
                .throttleBody(32, 1, TimeUnit.SECONDS)
        )
        val client = OkHttpClient.Builder().addInterceptor(interceptor()).build()

        val startedAt = System.nanoTime()
        val call = client.newCall(Request.Builder().url(server.url("/stream")).build())
        call.execute().use { response ->
            response.body!!.source().readUtf8Line() shouldBe lines.first()
            val elapsedMs = ((System.nanoTime() - startedAt) / 1_000_000).toInt()
            elapsedMs shouldBeLessThan 3_000
        }

        awaitEntry().responseBody!!.text shouldBe "(not read to the end, not captured)"
    }

    @Test
    fun chunkedJson_readCompletely_isCapturedAndRedacted() {
        server.enqueue(
            MockResponse()
                .setHeader("Content-Type", "application/json")
                .setChunkedBody("""{"idToken":"t","ok":true}""", 4)
        )
        val client = OkHttpClient.Builder().addInterceptor(interceptor()).build()

        client.newCall(Request.Builder().url(server.url("/")).build()).execute().use {
            it.body!!.string() shouldBe """{"idToken":"t","ok":true}"""
        }

        val entry = awaitEntry()
        entry.responseBody!!.text shouldBe """{"idToken":"[REDACTED]","ok":true}"""
        entry.responseBytes shouldBe 25L
    }
}
