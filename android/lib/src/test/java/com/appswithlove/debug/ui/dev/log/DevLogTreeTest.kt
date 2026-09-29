package com.appswithlove.debug.ui.dev.log

import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import org.junit.After
import org.junit.Test
import timber.log.Timber

class DevLogTreeTest {

    private val logHistory = LogHistory()

    @After
    fun tearDown() {
        Timber.uprootAll()
    }

    @Test
    fun log_withTagAndThrowable_keepsBoth() {
        val error = IllegalStateException("boom")
        Timber.plant(DevLogTree(DevLogWriter(logHistory)))

        Timber.tag("Network").e(error, "Request failed")

        val entry = logHistory.logEntries.value.single()
        entry.severity shouldBe DevLogSeverity.ERROR
        entry.tag shouldBe "Network"
        entry.throwable shouldBe error
        entry.toExportString() shouldContain "| ERROR | Network | Request failed"
    }
}
