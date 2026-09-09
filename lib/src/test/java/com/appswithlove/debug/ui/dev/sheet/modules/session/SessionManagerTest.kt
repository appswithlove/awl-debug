package com.appswithlove.debug.ui.dev.sheet.modules.session

import app.cash.turbine.test
import com.appswithlove.debug.api.session.SessionProvider
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Test

class SessionManagerTest {

    private class FakeSessionProvider(
        override val label: String,
        private val tokenState: MutableStateFlow<String?> = MutableStateFlow(null),
    ) : SessionProvider {
        override val token: Flow<String?> = tokenState

        var setTokenCalled = false
        var lastSetValue: String? = null

        override val onSetToken: suspend (String?) -> Unit = { value ->
            setTokenCalled = true
            lastSetValue = value
            tokenState.value = value
        }

        fun emit(value: String?) {
            tokenState.value = value
        }
    }

    @Test
    fun states_initialValue_hasNullTokenForEachProvider() = runTest {
        val providerA = FakeSessionProvider("A")
        val providerB = FakeSessionProvider("B")

        val manager = SessionManager(listOf(providerA, providerB))

        val states = manager.states.value
        states shouldHaveSize 2
        states[0].provider shouldBe providerA
        states[0].token shouldBe null
        states[1].provider shouldBe providerB
        states[1].token shouldBe null
    }

    @Test
    fun states_whenProviderTokenEmits_emitsUpdatedToken() = runTest {
        val provider = FakeSessionProvider("A")
        val manager = SessionManager(listOf(provider))

        manager.states.test {
            awaitItem().first().token shouldBe null
            provider.emit("token-123")
            awaitItem().first().token shouldBe "token-123"
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun setToken_invokesProviderOnSetToken() = runTest {
        val provider = FakeSessionProvider("A")
        val manager = SessionManager(listOf(provider))

        manager.setToken(provider, "new-token")

        provider.setTokenCalled shouldBe true
        provider.lastSetValue shouldBe "new-token"
    }
}
