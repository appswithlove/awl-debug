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
) {
    val hasAnyModuleEnabled = showLogsModule || showPerformanceModule ||
            showPermissionsModule || showAccessibilityModule || showDeeplinksModule ||
            (showFcmPushTokenModule && fcmTokenProvider != null) || showTestCrashesModule ||
            (showSessionModule && sessionProviders.isNotEmpty())
}
