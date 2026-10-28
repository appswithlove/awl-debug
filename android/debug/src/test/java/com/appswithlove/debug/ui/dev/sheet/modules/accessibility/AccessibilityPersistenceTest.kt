package com.appswithlove.debug.ui.dev.sheet.modules.accessibility

import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.domain.storage.DevStore
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AccessibilityPersistenceTest {

    @Test
    fun setAccessibility_isReadBackFromTheStore() = runTest {
        val settings = AccessibilitySettings(useSystemFontScale = false, fontScale = 1.3f, appearance = Appearance.Dark)

        DevStore(ApplicationProvider.getApplicationContext()).setAccessibility(settings)

        DevStore(ApplicationProvider.getApplicationContext()).accessibility.first() shouldBe settings
    }
}
