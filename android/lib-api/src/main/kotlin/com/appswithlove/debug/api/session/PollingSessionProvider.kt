package com.appswithlove.debug.api.session

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow

/**
 * [SessionProvider] for token sources without a [Flow], such as a suspend getter on a token store.
 * The token is read every [pollIntervalMillis] while the panel shows it.
 */
class PollingSessionProvider(
    override val label: String,
    private val pollIntervalMillis: Long = 1_000,
    override val onSetToken: (suspend (String?) -> Unit)? = null,
    override val onLogin: (suspend () -> Unit)? = null,
    override val onRefresh: (suspend () -> Unit)? = null,
    override val onLogout: (suspend () -> Unit)? = null,
    override val onInvalidate: (suspend () -> Unit)? = null,
    private val readToken: suspend () -> String?,
) : SessionProvider {
    override val token: Flow<String?> = flow {
        while (true) {
            emit(readToken())
            delay(pollIntervalMillis)
        }
    }.distinctUntilChanged()
}
