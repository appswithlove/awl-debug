package com.appswithlove.debug.ui.dev.network

import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.ui.dev.sheet.modules.network.redactedCountText
import io.kotest.matchers.shouldBe
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.junit.Test

class NetworkRedactorDefaultsTest {

    private val redactor = NetworkRedactor(DevNetworkConfig())

    @Test
    fun json_defaultFields_areRedacted() {
        val counter = NetworkRedactor.Counter()

        val redacted = redactor.json(
            """{"credential":"c","token":"t","secret":"s","api_key":"k","nested":{"password":"p"},"name":"n"}""",
            counter,
        )

        redacted shouldBe
            """{"credential":"[REDACTED]","token":"[REDACTED]","secret":"[REDACTED]","api_key":"[REDACTED]","nested":{"password":"[REDACTED]"},"name":"n"}"""
        counter.count shouldBe 5
    }

    @Test
    fun url_defaultQueryParams_matchIgnoringCaseAndSeparators() {
        val counter = NetworkRedactor.Counter()

        val url = redactor.url("https://api.example.com/a?api_key=1&Access-Token=2&refresh_token=3&page=2".toHttpUrl(), counter)

        url shouldBe "https://api.example.com/a?api_key=[REDACTED]&Access-Token=[REDACTED]&refresh_token=[REDACTED]&page=2"
        counter.count shouldBe 3
    }

    @Test
    fun redactedCountText_usesSingularForOne() {
        redactedCountText(0) shouldBe ""
        redactedCountText(1) shouldBe "1 value redacted"
        redactedCountText(3) shouldBe "3 values redacted"
    }
}
