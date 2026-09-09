package com.appswithlove.debug.ui.dev.sheet.modules.session

import com.appswithlove.debug.api.session.SessionProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

class SessionManager(providers: List<SessionProvider>) {

    data class ProviderState(
        val provider: SessionProvider,
        val token: String?,
    )

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    val states: StateFlow<List<ProviderState>> = run {
        val flows: List<Flow<ProviderState>> = providers.map { provider ->
            provider.token.map { token -> ProviderState(provider, token) }
        }
        combine(flows) {
            it.toList()
        }.stateIn(
            scope = scope,
            started = SharingStarted.Eagerly,
            initialValue = providers.map { ProviderState(it, null) },
        )
    }

    suspend fun setToken(provider: SessionProvider, value: String?) {
        provider.onSetToken?.invoke(value)
    }
}
