package com.appswithlove.debug.feedback.attachments

import com.appswithlove.debug.api.AwlDistribution
import com.appswithlove.debug.feedback.DeviceInfo
import com.appswithlove.debug.feedback.FeedbackConfig
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.test.runTest
import org.junit.Test
import java.util.Date
import java.util.TimeZone

class LogsAttachmentTest {

    private val golden = javaClass.getResource("/golden/logs.txt")!!.readText()
    private val config = FeedbackConfig(
        endpoint = "https://feedback.example.ch",
        appKey = "app-key",
        appVersion = "2.3.0",
        buildNumber = "1024",
        environment = "staging",
        distribution = AwlDistribution.Internal,
    )
    private val device = DeviceInfo(osVersion = "16", deviceModel = "Google Pixel 9", locale = "de-CH")

    /** 2026-09-29T10:15:31.000+02:00 */
    private val generatedAt = Date(1_790_669_731_000L)

    @Test
    fun fileMatchesGoldenFile() = runTest {
        val body = golden.substring(golden.indexOf("filters: ")).toByteArray()

        val file = captureLogsAttachment(config, device, generatedAt, source = { body }, timeZone = TimeZone.getTimeZone("Europe/Zurich"))

        file!!.toString(Charsets.UTF_8) shouldBe golden
    }

    @Test
    fun nothingWithoutDebugPanel() = runTest {
        captureLogsAttachment(config, device, generatedAt, source = null) shouldBe null
    }

    @Test
    fun nothingWhenTooLarge() = runTest {
        captureLogsAttachment(config, device, generatedAt, source = { ByteArray(LOGS_MAX_BYTES) }) shouldBe null
    }
}
