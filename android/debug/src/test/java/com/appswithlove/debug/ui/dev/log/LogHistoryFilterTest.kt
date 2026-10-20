package com.appswithlove.debug.ui.dev.log

import io.kotest.matchers.shouldBe
import org.junit.Test

class LogHistoryFilterTest {

    private val logHistory = LogHistory().apply {
        push(LogEntry(DevLogSeverity.ERROR, "payment failed", tag = "Checkout"))
        push(LogEntry(DevLogSeverity.INFO, "payment started", tag = "Checkout"))
        push(LogEntry(DevLogSeverity.ERROR, "sync failed", tag = "Sync"))
    }

    @Test
    fun filteredSnapshot_severityChip_keepsOnlyThatSeverity() {
        logHistory.filterBySeverity(DevLogSeverity.ERROR)

        logHistory.filteredSnapshot().map { it.message } shouldBe listOf("payment failed", "sync failed")
    }

    @Test
    fun filteredSnapshot_severityAndSearch_combine() {
        logHistory.filterBySeverity(DevLogSeverity.ERROR)
        logHistory.search("checkout")

        logHistory.filteredSnapshot().map { it.message } shouldBe listOf("payment failed")
    }
}
