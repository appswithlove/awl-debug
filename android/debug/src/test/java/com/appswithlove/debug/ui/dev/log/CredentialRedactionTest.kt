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

    @Test
    fun log_jsonFields_areRedactedAtAnyDepth() {
        logged("""Body: {"user":"max","password":"hunter2","auth":{"access_token":"a.b","expires":3600}}""") shouldBe
            """Body: {"user":"max","password":"[REDACTED]","auth":{"access_token":"[REDACTED]","expires":3600}}"""
    }

    @Test
    fun log_jsonFieldNonStringValues_areRedacted() {
        logged("""{"apiKey": 12345, "Credential": {"id": 1, "pin": "0000"}, "token": null, "ok": true}""") shouldBe
            """{"apiKey": "[REDACTED]", "Credential": "[REDACTED]", "token": "[REDACTED]", "ok": true}"""
    }

    @Test
    fun log_stringifiedJson_isRedacted() {
        logged("""payload="{\"refreshToken\":\"r1\",\"name\":\"x\"}"""") shouldBe
            """payload="{\"refreshToken\":\"[REDACTED]\",\"name\":\"x\"}""""
    }

    @Test
    fun log_truncatedJson_redactsToEnd() {
        logged("""{"clientSecret":"abc""") shouldBe """{"clientSecret":"[REDACTED]""""
    }

    @Test
    fun log_otherFieldsAndProse_areKept() {
        logged("""token rotation done, {"tokenType":"Bearer-less","secretary":"Ann"}""") shouldBe
            """token rotation done, {"tokenType":"Bearer-less","secretary":"Ann"}"""
    }
}
