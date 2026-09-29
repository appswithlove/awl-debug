package com.appswithlove.debug.ui.dev.network

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldNotContain
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.util.TimeZone

class NetworkFormattingTest {

    private val defaultTimeZone = TimeZone.getDefault()

    @Before
    fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    @After
    fun tearDown() {
        TimeZone.setDefault(defaultTimeZone)
    }

    @Test
    fun toCurl_postWithJsonBody_matchesSpecFixture() {
        val entry = networkEntry(
            method = "POST",
            requestHeaders = listOf("Authorization" to "[REDACTED]"),
            requestBody = CapturedBody("""{"name":"Test"}""", "application/json"),
        )

        entry.toCurl() shouldBe """
            curl -X POST 'https://api.example.com/v1/items?page=2' \
              -H 'Content-Type: application/json' \
              -H 'Authorization: [REDACTED]' \
              --data-raw '{"name":"Test"}'
        """.trimIndent()
    }

    @Test
    fun toCurl_getWithoutBody_omitsMethod() {
        networkEntry().toCurl() shouldBe "curl 'https://api.example.com/v1/items?page=2'"
    }

    @Test
    fun toCurl_singleQuotes_areEscaped() {
        val entry = networkEntry(
            method = "POST",
            requestBody = CapturedBody("it's", "text/plain"),
        )

        entry.toCurl() shouldContain """--data-raw 'it'\''s'"""
    }

    @Test
    fun toCurl_truncatedOrPlaceholderBody_isReplacedWithComment() {
        val truncated = networkEntry(
            method = "POST",
            requestBody = CapturedBody("abc", "text/plain", truncated = true, originalBytes = 10),
        )
        val oneShot = networkEntry(
            method = "PUT",
            requestBody = CapturedBody("(one-shot body, not captured)", null, isContent = false),
        )

        truncated.toCurl() shouldContain "\n# body not included: truncated after 3 bytes"
        truncated.toCurl() shouldNotContain "--data-raw"
        oneShot.toCurl() shouldContain "\n# body not included: (one-shot body, not captured)"
    }

    @Test
    fun networkExportText_followsFilters() {
        val entries = listOf(
            networkEntry(id = 1, method = "POST", status = 404, url = "https://api.example.com/a"),
            networkEntry(id = 2, method = "GET", status = 404, url = "https://api.example.com/b"),
            networkEntry(id = 3, method = "POST", status = 200, url = "https://api.example.com/c"),
            networkEntry(id = 4, method = "POST", status = 404, url = "https://cdn.example.com/d"),
        )
        val filter = NetworkFilter(
            excludedMethods = setOf("GET"),
            excludedStatusClasses = StatusClass.entries.toSet() - StatusClass.ClientError,
            excludedHosts = setOf("cdn.example.com"),
        )

        val text = networkExportText(
            entries = entries.filteredAndSorted(filter, NetworkSort.OldestFirst),
            filter = filter,
            devConfig = null,
            exportedAtMillis = FIXTURE_TIME,
        )

        text shouldContain "Requests: 1\n"
        text shouldContain "Hidden methods: GET"
        text shouldContain "2026-09-29T10:15:31.123Z POST 404 120ms https://api.example.com/a\n"
        text shouldNotContain "/b\n"
        text shouldNotContain "/c\n"
        text shouldNotContain "/d\n"
    }

    @Test
    fun filter_search_matchesUrlMethodAndStatus() {
        val entries = listOf(
            networkEntry(id = 1, method = "DELETE", status = 204, url = "https://api.example.com/items/1"),
            networkEntry(id = 2, method = "GET", status = 0, url = "https://api.example.com/offline", error = "timeout"),
        )

        entries.filteredAndSorted(NetworkFilter(query = "delete"), NetworkSort.OldestFirst).map { it.id } shouldBe listOf(1L)
        entries.filteredAndSorted(NetworkFilter(query = "204"), NetworkSort.OldestFirst).map { it.id } shouldBe listOf(1L)
        entries.filteredAndSorted(NetworkFilter(query = "offline"), NetworkSort.OldestFirst).map { it.id } shouldBe listOf(2L)
        entries.filteredAndSorted(NetworkFilter(query = "failed"), NetworkSort.OldestFirst).map { it.id } shouldBe listOf(2L)
    }
}
