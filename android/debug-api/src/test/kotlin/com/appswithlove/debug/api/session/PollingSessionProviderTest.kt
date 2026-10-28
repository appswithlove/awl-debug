package com.appswithlove.debug.api.session

import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Test

class PollingSessionProviderTest {

    @Test
    fun token_pollsTheSuspendGetterAndEmitsChangesOnly() = runTest {
        val values = ArrayDeque(listOf("a", "a", null, "b"))
        val provider = PollingSessionProvider(label = "Access Token", pollIntervalMillis = 100) { values.removeFirst() }

        provider.token.take(3).toList() shouldBe listOf("a", null, "b")
    }

    @Test
    fun token_failingRead_emitsNullAndKeepsPolling() = runTest {
        val values = ArrayDeque(listOf<() -> String?>({ "a" }, { error("KeyStore unavailable") }, { "b" }))
        val provider = PollingSessionProvider(label = "Access Token", pollIntervalMillis = 100) { values.removeFirst()() }

        provider.token.take(3).toList() shouldBe listOf("a", null, "b")
    }
}
