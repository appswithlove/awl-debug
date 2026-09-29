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
}
