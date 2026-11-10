package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.ui.dev.network.NetworkLogStore
import io.kotest.matchers.longs.shouldBeLessThan
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okio.Buffer
import org.junit.After
import org.junit.Test
import java.lang.management.ManagementFactory
import java.util.concurrent.TimeUnit

/**
 * Compares a client with [DevHttpLogInterceptor] to a plain one against a local server. Prints `PERF` lines; the
 * bounds are loose, so the tests only fail when capturing slows the app down by an order of magnitude.
 */
class NetworkCapturePerformanceTest {

    private val server = MockWebServer().apply { start() }
    private val store = NetworkLogStore()
    private val collector = object : DevLogCollector {
        override fun setTrackLogs(track: Boolean) = Unit
        override fun log(log: Log) = Unit
        override fun setMaxSize(size: Int) = Unit
    }
    private val threads = ManagementFactory.getThreadMXBean() as com.sun.management.ThreadMXBean

    @After
    fun tearDown() {
        server.shutdown()
    }

    private fun client(captured: Boolean) = OkHttpClient.Builder()
        .apply { if (captured) addInterceptor(DevHttpLogInterceptor(DevNetworkConfig(), store, collector)) }
        .build()

    private fun report(name: String, plain: Double, captured: Double, unit: String) {
        println("PERF %s plain=%.2f%s captured=%.2f%s".format(name, plain, unit, captured, unit))
    }

    /** Wall time in ms and bytes allocated by the calling thread. */
    private fun measure(block: () -> Unit): Pair<Double, Long> {
        val threadId = Thread.currentThread().id
        val allocatedBefore = threads.getThreadAllocatedBytes(threadId)
        val startedAt = System.nanoTime()
        block()
        return (System.nanoTime() - startedAt) / 1e6 to threads.getThreadAllocatedBytes(threadId) - allocatedBefore
    }

    @Test
    fun manySmallRequests() {
        val count = 500
        fun run(captured: Boolean): Double {
            repeat(count) {
                server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setBody("""{"id":1,"token":"t"}"""))
            }
            val client = client(captured)
            return measure {
                repeat(count) {
                    client.newCall(Request.Builder().url(server.url("/small")).build()).execute().use { it.body!!.string() }
                }
            }.first / count
        }
        run(captured = false) // warm-up
        val plain = run(captured = false)
        val captured = run(captured = true)
        report("small-sequential-per-request", plain, captured, "ms")
        captured.toLong() shouldBeLessThan (plain * 10 + 5).toLong()
    }

    @Test
    fun largeChunkedJsonResponse() {
        val size = 30 * 1024 * 1024
        val body = "a".repeat(size)
        fun run(captured: Boolean): Pair<Double, Long> {
            server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setChunkedBody(body, 64 * 1024))
            val client = client(captured)
            return measure {
                client.newCall(Request.Builder().url(server.url("/large")).build()).execute().use { response ->
                    val sink = Buffer()
                    val source = response.body!!.source()
                    while (source.read(sink, 64 * 1024) != -1L) sink.clear()
                }
            }
        }
        run(captured = false) // warm-up
        val plain = run(captured = false)
        val captured = run(captured = true)
        report("large-30MB-chunked-json-duration", plain.first, captured.first, "ms")
        report("large-30MB-chunked-json-allocated", plain.second / 1e6, captured.second / 1e6, "MB")
        captured.first.toLong() shouldBeLessThan (plain.first * 10 + 1_000).toLong()
    }

    @Test
    fun streamedJsonTimeToFirstLine() {
        val lines = List(20) { """{"line":$it}""" }.joinToString("\n", postfix = "\n")
        fun run(captured: Boolean): Double {
            server.enqueue(
                MockResponse()
                    .setHeader("Content-Type", "application/json")
                    .setChunkedBody(lines, 16)
                    .throttleBody(64, 250, TimeUnit.MILLISECONDS)
            )
            val client = client(captured)
            var firstLineMs = 0.0
            val startedAt = System.nanoTime()
            client.newCall(Request.Builder().url(server.url("/stream")).build()).execute().use { response ->
                response.body!!.source().readUtf8Line()
                firstLineMs = (System.nanoTime() - startedAt) / 1e6
            }
            return firstLineMs
        }
        val plain = run(captured = false)
        val captured = run(captured = true)
        report("stream-json-time-to-first-line", plain, captured, "ms")
    }

    /** Redacting a JSON body close to the 1 MB limit, until the app has the response. */
    @Test
    fun largeJsonRedaction() {
        val json = (0 until 20_000).joinToString(",", "[", "]") { """{"id":$it,"token":"secret$it"}""" }
        fun run(captured: Boolean): Double {
            server.enqueue(MockResponse().setHeader("Content-Type", "application/json").setBody(json))
            val client = client(captured)
            return measure {
                client.newCall(Request.Builder().url(server.url("/json")).build()).execute().use { it.body!!.string() }
            }.first
        }
        run(captured = false) // warm-up
        run(captured = true) // warm-up
        val plain = run(captured = false)
        val captured = run(captured = true)
        report("json-${json.length / 1024}KB-until-app-has-body", plain, captured, "ms")
    }
}
