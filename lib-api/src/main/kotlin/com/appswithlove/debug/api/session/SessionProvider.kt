package com.appswithlove.debug.api.session

import kotlinx.coroutines.flow.Flow

interface SessionProvider {
    val label: String
    val token: Flow<String?>

    /** When non-null, "Edit" (and "Delete" while logged in) buttons are shown that set the token via this. */
    val onSetToken: (suspend (String?) -> Unit)? get() = null

    /** When non-null, a "Login" button is shown (while logged out) that invokes this. */
    val onLogin: (suspend () -> Unit)? get() = null

    /** When non-null, a "Refresh" button is shown (while logged in) that invokes this. */
    val onRefresh: (suspend () -> Unit)? get() = null

    /** When non-null, a "Logout" button is shown (while logged in) that invokes this. */
    val onLogout: (suspend () -> Unit)? get() = null
}
