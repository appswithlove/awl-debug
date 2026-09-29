package com.appswithlove.debug.api

import com.appswithlove.debug.api.session.SessionProvider

data class DevModulesConfig(
    val showLogsModule: Boolean = true,
    val showPerformanceModule: Boolean = true,
    val showPermissionsModule: Boolean = true,
    val showAccessibilityModule: Boolean = true,
    val showDeeplinksModule: Boolean = true,
    val deeplinks: List<DeeplinkItem> = emptyList(),
    val showFcmPushTokenModule: Boolean = true,
    val fcmTokenProvider: FcmTokenProvider? = null,
    val showTestCrashesModule: Boolean = true,
    val showSessionModule: Boolean = true,
    val sessionProviders: List<SessionProvider> = emptyList(),
    /** Shown once a `DevHttpLogInterceptor` has been created. */
    val showNetworkModule: Boolean = true,
    /** "Clear App Data" resets the app to a fresh install after a confirmation. */
    val showClearAppDataModule: Boolean = true,
    /** Default of the "Show version overlay" switch; testers can change it on the device. */
    val showVersionOverlay: Boolean = true,
    /**
     * Opens deeplinks fired from the panel, for example with the app's navigator. `null` starts an
     * `ACTION_VIEW` intent for the app's package. With a handler, forward launch intents to
     * `AwlDebug.handleDeeplinkIntent` so delayed deeplinks from notifications reach it too.
     */
    val deeplinkHandler: ((String) -> Unit)? = null,
) {
    val hasAnyModuleEnabled = showLogsModule || showPerformanceModule ||
            showPermissionsModule || showAccessibilityModule || showDeeplinksModule ||
            (showFcmPushTokenModule && fcmTokenProvider != null) || showTestCrashesModule ||
            (showSessionModule && sessionProviders.isNotEmpty()) || showNetworkModule || showClearAppDataModule
}
