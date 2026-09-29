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
) {
    val hasAnyModuleEnabled = showLogsModule || showPerformanceModule ||
            showPermissionsModule || showAccessibilityModule || showDeeplinksModule ||
            (showFcmPushTokenModule && fcmTokenProvider != null) || showTestCrashesModule ||
            (showSessionModule && sessionProviders.isNotEmpty()) || showNetworkModule || showClearAppDataModule
}
