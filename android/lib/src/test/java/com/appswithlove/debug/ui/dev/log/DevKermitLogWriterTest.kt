package com.appswithlove.debug.ui.dev.log

import co.touchlab.kermit.Logger
import co.touchlab.kermit.Severity
import co.touchlab.kermit.StaticConfig
import io.kotest.matchers.shouldBe
import org.junit.Test

class DevKermitLogWriterTest {

    private val logHistory = LogHistory()
    private val logger = Logger(
        StaticConfig(minSeverity = Severity.Verbose, logWriterList = listOf(DevKermitLogWriter(DevLogWriter(logHistory)))),
        tag = "Auth",
    )

    @Test
    fun log_withTagAndThrowable_keepsBothAndRedactsCredentials() {
        val error = IllegalStateException("x")

        logger.e(error) { "failed with Bearer abc.def" }

        val entry = logHistory.logEntries.value.single()
        entry.severity shouldBe DevLogSeverity.ERROR
        entry.tag shouldBe "Auth"
        entry.throwable shouldBe error
        entry.message shouldBe "failed with Bearer [REDACTED]"
    }

    @Test
    fun log_verboseAndBlankTag_mapToDebugWithoutTag() {
        logger.withTag("").v { "details" }

        val entry = logHistory.logEntries.value.single()
        entry.severity shouldBe DevLogSeverity.DEBUG
        entry.tag shouldBe null
    }
}
