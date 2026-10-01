package com.appswithlove.debug.feedback.reporting

import com.appswithlove.debug.feedback.AwlDistribution
import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevNetworkRecord
import com.appswithlove.debug.ui.dev.log.DevHttpLogInterceptor
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.longs.shouldBeLessThan
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldMatch
import io.kotest.matchers.string.shouldNotContain
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.zip.GZIPInputStream

/**
 * Builds real batches from requests that `DevHttpLogInterceptor` captures and hands to network listeners. Every batch
 * is also written to `feedback/build/contract/` for a local schema check:
 * `uvx --from check-jsonschema check-jsonschema --schemafile <session-batch.v1.schema.json>` with every file there.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RemoteReporterTest {

    @get:Rule
    val folder = TemporaryFolder()

    private val context = RuntimeEnvironment.getApplication()
    private val server = MockWebServer().apply { start() }
    private val executor = Executors.newSingleThreadScheduledExecutor()
    private val records = LinkedBlockingQueue<DevNetworkRecord>()
    private val listener = AwlDebugExtensions.addNetworkListener { records += it }
    private var now = 1_790_000_000_000L
    private var elapsed = 0L

    private val config = RemoteReportingConfig(
        endpoint = "https://feedback.example.ch/",
        appKey = "fbk_test",
        environment = "staging",
        distribution = AwlDistribution.Internal,
    )

    @After
    fun tearDown() {
        listener.close()
        server.shutdown()
        executor.shutdownNow()
    }

    private fun reporter(
        config: RemoteReportingConfig = this.config,
        buffer: ReportingBuffer = ReportingBuffer(folder.root) { now },
        appUserId: String? = null,
    ) = RemoteReporter(context, config, buffer, executor, appUserId, { now }, { elapsed }, { null })

    private val client by lazy {
        OkHttpClient.Builder()
            .addInterceptor(DevHttpLogInterceptor(DevNetworkConfig()))
            .readTimeout(300, TimeUnit.MILLISECONDS)
            .build()
    }

    /** Sends [request] and returns what the network listener got for it; failed requests are captured too. */
    private fun call(request: Request): DevNetworkRecord {
        try {
            client.newCall(request).execute().use { it.body?.string() }
        } catch (_: Exception) {
            // Recorded as a failure.
        }
        return checkNotNull(records.poll(5, TimeUnit.SECONDS)) { "No record for ${request.url}" }
    }

    private fun ReportingBuffer.batches(): List<JsonObject> = sealedBatches().map { file ->
        val text = GZIPInputStream(file.inputStream()).bufferedReader().readText()
        CONTRACT_DIR.apply { mkdirs() }.resolve(file.name.removeSuffix(".gz")).writeText(text)
        Json.parseToJsonElement(text).jsonObject
    }

    private fun JsonObject.array(key: String): JsonArray = this[key]?.jsonArray ?: JsonArray(emptyList())
    private fun JsonObject.string(key: String): String? = this[key]?.jsonPrimitive?.content

    @Test
    fun `batch contains redacted requests, failures without status and metrics`() {
        val buffer = ReportingBuffer(folder.root) { now }
        val reporter = reporter(config.copy(endpoint = server.url("/svc/").toString()), buffer, appUserId = "42")
        reporter.start().get()
        reporter.onForeground().get()

        server.enqueue(MockResponse().setBody("{\"token\":\"secret\"}").setHeader("Content-Type", "application/json"))
        val loginRecord = call(
            Request.Builder().url(server.url("/v1/login"))
                .header("Authorization", "Bearer abc")
                .header("X-Api-Key", "k")
                .post("{\"password\":\"p\"}".toRequestBody("application/json".toMediaType()))
                .build(),
        )
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        val slowRecord = call(Request.Builder().url(server.url("/slow")).build())
        server.enqueue(MockResponse().setBody("ok"))
        val ownRecord = call(Request.Builder().url(server.url("/svc/v1/sessions/batch")).build()) // own traffic, never reported
        listOf(loginRecord, slowRecord, ownRecord).forEach(reporter::onNetworkRecord)
        reporter.onMetric(ReportingMetricSample(now, cpuPercent = 12.34, ramBytes = 1_000, batteryPercent = 80, uiFreezeMs = 0))
        reporter.onMetric(ReportingMetricSample(now)) // no values: left out
        now += 5_000
        reporter.onBackground().get()

        val batch = buffer.batches().single()
        val session = batch["session"]!!.jsonObject
        session.string("distribution") shouldBe "internal"
        session.string("platform") shouldBe "android"
        session.string("endedAt").shouldNotBeNull()
        session.string("userIdentifier")!! shouldMatch Regex("^[0-9a-f]{64}$")
        batch.toString() shouldNotContain "\"42\""

        val logs = batch.array("networkLogs")
        logs shouldHaveSize 2
        val login = logs[0].jsonObject
        login["status"]!!.jsonPrimitive.content shouldBe "200"
        login["requestHeaders"]!!.jsonObject.string("authorization") shouldBe "[REDACTED]"
        login["requestHeaders"]!!.jsonObject.string("x-api-key") shouldBe "[REDACTED]"
        login["requestBody"].shouldBeNull()
        login["responseBody"].shouldBeNull()
        val failed = logs[1].jsonObject
        failed["status"].shouldBeNull()
        failed.string("error") shouldBe "timeout"

        val metrics = batch.array("metrics")
        metrics shouldHaveSize 1
        metrics[0].jsonObject.string("cpuPercent") shouldBe "12.3"
    }

    @Test
    fun `bodies are sent capped when enabled`() {
        val buffer = ReportingBuffer(folder.root) { now }
        val reporter = reporter(config.copy(captureBodies = true, maxBodyBytes = 10), buffer)
        reporter.onForeground().get()
        server.enqueue(MockResponse().setBody("0123456789abcdef").setHeader("Content-Type", "text/plain"))
        reporter.onNetworkRecord(call(Request.Builder().url(server.url("/text")).build()))
        reporter.flush().get()

        val body = buffer.batches().single().array("networkLogs")[0].jsonObject["responseBody"]!!.jsonObject
        body.string("text") shouldBe "0123456789"
        body.string("truncated") shouldBe "true"
        body.string("originalBytes") shouldBe "16"
    }

    @Test
    fun `large sessions are split into batches of at most 2000 entries`() {
        val buffer = ReportingBuffer(folder.root) { now }
        val reporter = reporter(buffer = buffer)
        reporter.onForeground().get()
        repeat(4_500) { reporter.onMetric(ReportingMetricSample(now + it, ramBytes = it.toLong() + 1)) }
        reporter.flush().get()

        val batches = buffer.batches()
        batches.map { it.array("metrics").size } shouldBe listOf(2_000, 2_000, 500)
        batches.map { it.string("batchId") }.toSet() shouldHaveSize 3
        buffer.sealedBatches().forEach { it.length() shouldBeLessThan ReportingBuffer.MAX_BATCH_GZIP_BYTES.toLong() }
    }

    @Test
    fun `full buffer drops the oldest entries and reports droppedCount`() {
        val buffer = ReportingBuffer(folder.root, maxBytes = 20_000) { now }
        val reporter = reporter(buffer = buffer)
        reporter.onForeground().get()
        repeat(500) { reporter.onMetric(ReportingMetricSample(now + it, ramBytes = it.toLong() + 1)) }
        reporter.flush().get()

        val batch = buffer.batches().single()
        val kept = batch.array("metrics").size
        batch["droppedCount"]!!.jsonPrimitive.long shouldBe (500 - kept).toLong()
        buffer.sizeBytes shouldBeLessThan 20_000
    }

    @Test
    fun `entries left by an earlier process go out with their own session and endedAt`() {
        val first = reporter()
        first.onForeground().get()
        first.onMetric(ReportingMetricSample(now + 1_234, ramBytes = 1))
        executor.submit {}.get()

        now += 60_000
        val buffer = ReportingBuffer(folder.root) { now }
        val second = reporter(buffer = buffer)
        second.start().get()
        second.onForeground().get()
        second.onMetric(ReportingMetricSample(now, ramBytes = 2))
        second.flush().get()

        val (old, current) = buffer.batches()
        old.array("metrics") shouldHaveSize 1
        old["session"]!!.jsonObject.string("endedAt") shouldBe ReportingJson.timestamp(now - 60_000 + 1_234)
        current["session"]!!.jsonObject.string("endedAt").shouldBeNull()
        current["session"]!!.jsonObject.string("id") shouldNotBe old["session"]!!.jsonObject.string("id")
    }

    @Test
    fun `new session after 30 minutes in the background`() {
        val buffer = ReportingBuffer(folder.root) { now }
        val reporter = reporter(buffer = buffer)
        reporter.onForeground().get()
        reporter.onBackground().get()
        elapsed += 29 * 60_000L
        now += 29 * 60_000L
        reporter.onForeground().get()
        reporter.onBackground().get()
        elapsed += 30 * 60_000L
        now += 30 * 60_000L
        reporter.onForeground().get()
        reporter.onMetric(ReportingMetricSample(now, ramBytes = 1))
        reporter.flush().get()

        val sessionIds = buffer.batches().map { it["session"]!!.jsonObject.string("id") }
        sessionIds shouldHaveSize 3 // endedAt of both background phases, then the new session
        sessionIds[0] shouldBe sessionIds[1]
        sessionIds[2] shouldNotBe sessionIds[0]
    }

    @Test
    fun `store builds record nothing`() {
        RemoteReporting.start(context, config.copy(distribution = AwlDistribution.Store))

        RemoteReporting.reporter.shouldBeNull()
        RemoteReporting.bufferDir(context).exists() shouldBe false
    }

    companion object {
        private val CONTRACT_DIR = File("build/contract")

        @JvmStatic
        @BeforeClass
        fun clearContractDir() {
            CONTRACT_DIR.deleteRecursively()
        }
    }
}
