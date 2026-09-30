package com.appswithlove.debug.feedback

import io.kotest.assertions.withClue
import io.kotest.matchers.shouldBe
import org.json.JSONObject
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.Date

@RunWith(RobolectricTestRunner::class)
class FeedbackMetadataTest {

    private val config = FeedbackConfig(
        endpoint = "https://feedback.example.com",
        appKey = "app-key",
        appVersion = "1.4.0",
        buildNumber = "812",
        environment = "staging",
    )
    private val device = DeviceInfo(osVersion = "16", deviceModel = "Google Pixel 9", locale = "de-CH")

    /** 2026-09-25T08:15:00.123Z, the timestamp of the fixture. */
    private val timestamp = Date(1_790_324_100_123L)

    @Test
    fun buildMetadataJson_withoutNewFields_matchesV1Fixture() {
        val json = JSONObject(
            buildMetadataJson(config, device, mapOf("screen" to "RecipeDetail", "recipeId" to "4711"), timestamp)
        )

        json.toMap() shouldBe JSONObject(fixture("metadata-v1-android.json")).toMap()
        json.has("distribution") shouldBe false
        json.has("reporter") shouldBe false
    }

    @Test
    fun buildMetadataJson_withDistributionAndReporter_sendsBoth() {
        val json = JSONObject(
            buildMetadataJson(
                config.copy(
                    distribution = AwlDistribution.Internal,
                    reporter = FeedbackReporter(name = "Test User", email = "test@example.com"),
                ),
                device,
                emptyMap(),
                timestamp,
            )
        )

        json.getString("distribution") shouldBe "internal"
        json.getJSONObject("reporter").toMap() shouldBe mapOf("name" to "Test User", "email" to "test@example.com")
    }

    @Test
    fun buildMetadataJson_capsScreenAndExtraKeys() {
        val longKey = "k".repeat(70)
        val json = JSONObject(
            buildMetadataJson(
                config.copy(reporter = FeedbackReporter(name = " ")),
                device,
                mapOf("screen" to "s".repeat(300), "" to "empty", " " to "blank", longKey to "value"),
                timestamp,
            )
        )

        json.getString("screen").length shouldBe 200
        val extra = json.getJSONObject("extra").toMap()
        extra.keys shouldBe setOf("screen", "k".repeat(64))
        json.has("reporter") shouldBe false
    }

    @Test
    fun buildMetadataJson_leavesOutEmailsTheServiceRejects() {
        fun sentEmail(email: String): String? = JSONObject(
            buildMetadataJson(config.copy(reporter = FeedbackReporter(name = "Sam", email = email)), device, emptyMap(), timestamp)
        ).getJSONObject("reporter").optString("email").ifEmpty { null }

        listOf("sam@example.ch.", "sam..tester@example.ch", ".sam@example.ch", "müller@example.ch", "sam@example.c", "sam@-example.ch")
            .forEach { email -> withClue(email) { sentEmail(email) shouldBe null } }
        sentEmail("first.last+qa@sub.example.co.uk") shouldBe "first.last+qa@sub.example.co.uk"
    }

    private fun fixture(name: String): String =
        requireNotNull(javaClass.classLoader?.getResource(name)) { "Missing fixture $name" }.readText()

    private fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
        when (val value = get(key)) {
            is JSONObject -> value.toMap()
            else -> value
        }
    }
}
