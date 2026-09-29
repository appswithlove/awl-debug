package com.appswithlove.debug.api

import com.appswithlove.debug.api.session.SessionProvider
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import org.junit.Test

class DevModulesConfigTest {

    @Test
    fun hasAnyModuleEnabled_defaultConfig_isTrue() {
        DevModulesConfig().hasAnyModuleEnabled shouldBe true
    }

    @Test
    fun hasAnyModuleEnabled_everythingDisabledAndNoProviders_isFalse() {
        allDisabled().hasAnyModuleEnabled shouldBe false
    }

    @Test
    fun hasAnyModuleEnabled_onlyTestCrashesEnabled_isTrue() {
        allDisabled().copy(showTestCrashesModule = true).hasAnyModuleEnabled shouldBe true
    }

    @Test
    fun hasAnyModuleEnabled_sessionEnabledButNoProviders_isFalse() {
        allDisabled().copy(showSessionModule = true).hasAnyModuleEnabled shouldBe false
    }

    @Test
    fun hasAnyModuleEnabled_sessionEnabledWithProvider_isTrue() {
        allDisabled().copy(
            showSessionModule = true,
            sessionProviders = listOf(FakeSessionProvider),
        ).hasAnyModuleEnabled shouldBe true
    }

    @Test
    fun hasAnyModuleEnabled_fcmEnabledButNoProvider_isFalse() {
        allDisabled().copy(showFcmPushTokenModule = true).hasAnyModuleEnabled shouldBe false
    }

    @Test
    fun hasAnyModuleEnabled_fcmEnabledWithProvider_isTrue() {
        allDisabled().copy(
            showFcmPushTokenModule = true,
            fcmTokenProvider = FakeFcmTokenProvider,
        ).hasAnyModuleEnabled shouldBe true
    }

    private fun allDisabled() = DevModulesConfig(
        showLogsModule = false,
        showPerformanceModule = false,
        showPermissionsModule = false,
        showAccessibilityModule = false,
        showDeeplinksModule = false,
        showFcmPushTokenModule = false,
        showTestCrashesModule = false,
        showSessionModule = false,
    )

    private object FakeSessionProvider : SessionProvider {
        override val label = "fake"
        override val token: Flow<String?> = flowOf(null)
    }

    private object FakeFcmTokenProvider : FcmTokenProvider {
        override val token: Flow<String?> = flowOf(null)
    }
}
