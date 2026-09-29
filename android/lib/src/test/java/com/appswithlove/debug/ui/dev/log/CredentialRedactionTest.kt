package com.appswithlove.debug.ui.dev.log

import io.kotest.matchers.shouldBe
import org.junit.Test

class CredentialRedactionTest {

    private val logHistory = LogHistory()
    private val writer = DevLogWriter(logHistory)

    private fun logged(message: String): String {
        writer.log(Log(DevLogSeverity.DEBUG, message))
        return logHistory.logEntries.value.last().message
    }

    @Test
    fun log_bearerToken_isRedacted() {
        logged("Authorization: Bearer abc.def") shouldBe "Authorization: Bearer [REDACTED]"
    }

    @Test
    fun log_basicCredentials_areRedacted() {
        logged("Authorization: Basic dXNlcjpwYXNz") shouldBe "Authorization: Basic [REDACTED]"
    }

    @Test
    fun log_basicInProse_isKept() {
        logged("Basic setup done") shouldBe "Basic setup done"
    }
}
