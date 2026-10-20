package com.appswithlove.debug.ui.dev.sheet.modules.accessibility

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createComposeRule
import io.kotest.matchers.shouldBe
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "notnight")
class AccessibilityOverrideTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private var isDark: Boolean? = null
    private var fontScale: Float? = null

    private fun render(settings: AccessibilitySettings) {
        composeTestRule.setContent {
            AccessibilityOverride(settings) {
                isDark = isSystemInDarkTheme()
                fontScale = LocalDensity.current.fontScale
            }
        }
        composeTestRule.waitForIdle()
    }

    @Test
    fun override_darkAndXxLarge_applyToContent() {
        render(AccessibilitySettings(useSystemFontScale = false, fontScale = 1.3f, appearance = Appearance.Dark))

        isDark shouldBe true
        fontScale shouldBe 1.3f
    }

    @Test
    fun override_system_keepsDeviceValues() {
        render(AccessibilitySettings())

        isDark shouldBe false
        fontScale shouldBe 1f
    }
}
