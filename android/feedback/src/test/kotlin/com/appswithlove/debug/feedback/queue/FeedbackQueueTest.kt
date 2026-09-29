package com.appswithlove.debug.feedback.queue

import com.appswithlove.debug.feedback.FeedbackPart
import com.appswithlove.debug.feedback.FeedbackReport
import com.appswithlove.debug.feedback.SendError
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import java.io.File
import java.util.UUID

@RunWith(RobolectricTestRunner::class)
class FeedbackQueueTest {

    private val server = MockWebServer()
    private val scope = CoroutineScope(SupervisorJob())
    private val directory = File(RuntimeEnvironment.getApplication().filesDir, "awl-debug/feedback-queue")
    private var now = 1_000_000L

    @Before
    fun setUp() {
        server.start()
        directory.deleteRecursively()
    }

    @After
    fun tearDown() {
        scope.cancel()
        server.shutdown()
    }

    @Test
    fun queuesUnavailableServiceAndRetriesWithSameIdempotencyKey() = runTest {
        val queue = queue()
        val report = report()
        server.enqueue(MockResponse().setResponseCode(503))

        queue.submit(report) shouldBe SubmitResult.Queued

        queuedKeys() shouldContainExactly listOf(report.idempotencyKey)
        queue.pendingCount.value shouldBe 1

        server.enqueue(MockResponse().setResponseCode(201).setBody("""{"id":"1","taskId":null}"""))
        queue.retry(ignoreBackoff = true)

        val first = server.takeRequest()
        val retried = server.takeRequest()
        first.headers["Idempotency-Key"] shouldBe report.idempotencyKey
        retried.headers["Idempotency-Key"] shouldBe report.idempotencyKey
        retried.body.readUtf8() shouldBe first.body.readUtf8().replace(first.boundary(), retried.boundary())
        queuedKeys() shouldBe emptyList()
        queue.pendingCount.value shouldBe 0
    }

    @Test
    fun doesNotQueueRejectedKey() = runTest {
        val queue = queue()
        server.enqueue(MockResponse().setResponseCode(401))

        queue.submit(report()) shouldBe SubmitResult.Failed(SendError.Unauthorized)

        queuedKeys() shouldBe emptyList()
        queue.pendingCount.value shouldBe 0
        server.requestCount shouldBe 1
    }

    @Test
    fun waitsForRetryAfterAndBackoff() = runTest {
        val queue = queue()
        server.enqueue(MockResponse().setResponseCode(429).addHeader("Retry-After", "120"))
        queue.submit(report()) shouldBe SubmitResult.Queued

        queue.retry(ignoreBackoff = true)
        now += 60_000
        queue.retry(ignoreBackoff = false)
        server.requestCount shouldBe 1

        server.enqueue(MockResponse().setResponseCode(503))
        now += 61_000
        queue.retry(ignoreBackoff = false)
        server.requestCount shouldBe 2

        // Second failure: backoff doubles to 60 s.
        now += 30_000
        queue.retry(ignoreBackoff = false)
        server.requestCount shouldBe 2
        server.enqueue(MockResponse().setResponseCode(201))
        now += 30_000
        queue.retry(ignoreBackoff = false)
        server.requestCount shouldBe 3
        queuedKeys() shouldBe emptyList()
    }

    @Test
    fun dropsOldestReportsBeyondLimit() = runTest {
        val queue = queue(maxReports = 2)
        val reports = List(3) { report() }
        reports.forEach { report ->
            server.enqueue(MockResponse().setResponseCode(503))
            queue.submit(report) shouldBe SubmitResult.Queued
            now += 1_000
        }

        queuedKeys() shouldContainExactly reports.drop(1).map { it.idempotencyKey }.sorted()
        queue.pendingCount.value shouldBe 2
    }

    private fun queue(maxReports: Int = 20) = FeedbackQueue(directory = directory, clock = { now }, scope = scope, maxReports = maxReports)

    private fun report() = FeedbackReport(
        idempotencyKey = UUID.randomUUID().toString(),
        endpoint = server.url("/").toString(),
        appKey = "app-key",
        text = "Button is cut off",
        metadataJson = "{}",
        parts = listOf(FeedbackPart(name = "screenshot", fileName = "screenshot.jpg", mimeType = "image/jpeg", bytes = byteArrayOf(1, 2, 3))),
    )

    private fun queuedKeys(): List<String> = directory.listFiles().orEmpty().map { it.name }.sorted()

    private fun okhttp3.mockwebserver.RecordedRequest.boundary(): String = headers["Content-Type"]!!.substringAfter("boundary=")
}
