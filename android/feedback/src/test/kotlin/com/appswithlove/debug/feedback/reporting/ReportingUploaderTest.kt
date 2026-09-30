package com.appswithlove.debug.feedback.reporting

import com.appswithlove.debug.feedback.AwlDistribution
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.zip.GZIPInputStream

/** Sends real batches built by [RemoteReporter] to a local server and checks what stays in the buffer. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ReportingUploaderTest {

    @get:Rule
    val folder = TemporaryFolder()

    private val context = RuntimeEnvironment.getApplication()
    private val server = MockWebServer().apply { start() }
    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var now = 1_790_000_000_000L
    private var networkAllowed = true
    private var stopped = false
    private val status = MutableStateFlow(ReportingStatus(isConfigured = true))
    private val buffer = ReportingBuffer(folder.apply { create() }.root) { now }

    private val config = RemoteReportingConfig(
        endpoint = server.url("/").toString(),
        appKey = "fbk_test",
        environment = "staging",
        distribution = AwlDistribution.Internal,
    )
    private val reporter = RemoteReporter(context, config, buffer, executor, null, { now }, { 0L }, { null }, status)
    private val uploader = ReportingUploader(
        bufferExecutor = executor,
        buffer = buffer,
        sender = ReportingSender(config.endpoint, config.appKey, clock = { now }),
        status = status,
        canSend = { networkAllowed },
        clock = { now },
        onStopped = { stopped = true },
    )

    @After
    fun tearDown() {
        uploader.shutdown()
        server.shutdown()
        executor.shutdownNow()
    }

    /** Records [count] metric samples and seals them into one batch. */
    private fun sealBatch(count: Int = 1) {
        reporter.onForeground().get()
        repeat(count) { reporter.onMetric(ReportingMetricSample(now + it, ramBytes = 1L + it)) }
        reporter.flush().get()
    }

    private fun upload(ignoreBackoff: Boolean = false) = uploader.upload(ignoreBackoff).get(5, TimeUnit.SECONDS)

    private fun takeRequest(): RecordedRequest = server.takeRequest(1, TimeUnit.SECONDS).shouldNotBeNull()

    private fun RecordedRequest.batchId(): String {
        val json = GZIPInputStream(body.clone().inputStream()).bufferedReader().readText()
        return Json.parseToJsonElement(json).jsonObject["batchId"]!!.jsonPrimitive.content
    }

    @Test
    fun `accepted batch is sent gzipped with the app key and leaves the buffer`() {
        sealBatch(count = 3)
        status.value.pendingEntries shouldBe 3
        server.enqueue(MockResponse().setBody("{\"status\":\"accepted\"}"))

        upload()

        val request = takeRequest()
        request.method shouldBe "POST"
        request.path shouldBe "/v1/sessions/batch"
        request.getHeader("X-App-Key") shouldBe "fbk_test"
        request.getHeader("Content-Encoding") shouldBe "gzip"
        request.getHeader("Content-Type") shouldBe "application/json"
        request.batchId().shouldNotBeNull()
        buffer.sealedBatches() shouldHaveSize 0
        status.value.pendingEntries shouldBe 0
        status.value.lastSentMillis shouldBe now
    }

    @Test
    fun `server error keeps the batch and the retry sends the same bytes after the backoff`() {
        sealBatch()
        server.enqueue(MockResponse().setResponseCode(503))
        upload()
        val first = takeRequest()
        buffer.sealedBatches() shouldHaveSize 1
        status.value.isRetrying shouldBe true

        upload() // backoff of 30 s not over
        server.requestCount shouldBe 1

        now += ReportingUploader.MIN_BACKOFF_MS
        server.enqueue(MockResponse().setBody("{\"status\":\"accepted\"}"))
        upload()
        val second = takeRequest()
        second.body.readByteArray().contentEquals(first.body.readByteArray()) shouldBe true
        buffer.sealedBatches() shouldHaveSize 0
        status.value.isRetrying shouldBe false
    }

    @Test
    fun `network failure keeps the batch, a new network retries at once with the same batchId`() {
        sealBatch()
        val sealedBytes = buffer.sealedBatches().single().readBytes()
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AT_START))
        upload()
        takeRequest()
        buffer.sealedBatches() shouldHaveSize 1
        status.value.isRetrying shouldBe true

        server.enqueue(MockResponse().setBody("{\"status\":\"duplicate\"}"))
        upload(ignoreBackoff = true)
        takeRequest().body.readByteArray().contentEquals(sealedBytes) shouldBe true
        buffer.sealedBatches() shouldHaveSize 0
    }

    @Test
    fun `retry after is respected even when the backoff is ignored`() {
        sealBatch()
        server.enqueue(MockResponse().setResponseCode(429).setHeader("Retry-After", "120"))
        upload()
        takeRequest()

        now += 60_000
        upload(ignoreBackoff = true)
        server.requestCount shouldBe 1

        now += 60_000
        server.enqueue(MockResponse().setBody("{\"status\":\"accepted\"}"))
        upload(ignoreBackoff = true)
        server.requestCount shouldBe 2
        buffer.sealedBatches() shouldHaveSize 0
    }

    @Test
    fun `rejected batches are dropped and the next one is still sent`() {
        sealBatch()
        sealBatch()
        sealBatch()
        server.enqueue(MockResponse().setResponseCode(400))
        server.enqueue(MockResponse().setResponseCode(422))
        server.enqueue(MockResponse().setResponseCode(413))

        upload()

        server.requestCount shouldBe 3
        buffer.sealedBatches() shouldHaveSize 0
        status.value.rejectedStatus shouldBe 413
    }

    @Test
    fun `401 and 403 stop sending until the next start`() {
        sealBatch()
        sealBatch()
        server.enqueue(MockResponse().setResponseCode(403).setBody("{\"error\":\"reporting_disabled\"}"))

        upload()
        upload(ignoreBackoff = true)
        now += ReportingUploader.MAX_BACKOFF_MS
        upload(ignoreBackoff = true)

        server.requestCount shouldBe 1
        status.value.stoppedStatus shouldBe 403
        status.value.isOn shouldBe false
        stopped shouldBe true
        buffer.sealedBatches() shouldHaveSize 2 // kept for a later start
    }

    @Test
    fun `nothing is sent while the network is not allowed or sending is off`() {
        sealBatch()
        networkAllowed = false
        upload(ignoreBackoff = true)
        status.value.isWaitingForUnmeteredNetwork shouldBe true

        networkAllowed = true
        status.value = status.value.copy(isSendingEnabled = false)
        upload(ignoreBackoff = true)
        server.requestCount shouldBe 0

        status.value = status.value.copy(isSendingEnabled = true)
        server.enqueue(MockResponse().setBody("{\"status\":\"accepted\"}"))
        upload(ignoreBackoff = true)
        server.requestCount shouldBe 1
        status.value.isWaitingForUnmeteredNetwork shouldBe false
        status.value.sessionId.shouldNotBeNull()
        status.value.rejectedStatus.shouldBeNull()
    }
}
