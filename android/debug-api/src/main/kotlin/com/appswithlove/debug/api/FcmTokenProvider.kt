package com.appswithlove.debug.api

import kotlinx.coroutines.flow.Flow

/**
 * Supplies the FCM push token shown in the debug sheet, plus optional refresh
 * and revoke actions. Implemented by the integrating app so the library stays
 * free of any Firebase dependency.
 *
 * Example:
 * ```
 * object AppFcmTokenProvider : FcmTokenProvider {
 *     override val token = MutableStateFlow<String?>(null)
 *
 *     override val onRefresh: suspend () -> Unit = {
 *         FirebaseMessaging.getInstance().deleteToken().await()
 *         token.value = FirebaseMessaging.getInstance().token.await()
 *     }
 *
 *     override val onRevoke: suspend () -> Unit = {
 *         FirebaseMessaging.getInstance().deleteToken().await()
 *         token.value = null
 *     }
 * }
 * ```
 */
interface FcmTokenProvider {
    /** Observed for display; emit a new value to update the shown token. */
    val token: Flow<String?>

    /** When non-null, a "Refresh" button is shown that invokes this. */
    val onRefresh: (suspend () -> Unit)? get() = null

    /** When non-null, a "Revoke" button is shown that invokes this. */
    val onRevoke: (suspend () -> Unit)? get() = null
}
