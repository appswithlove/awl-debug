package com.appswithlove.debug.ui.dev.sheet.modules.accessibility

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.theme.DevTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class AccessibilityModuleScreenshotTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun systemFontScale() {
        composeTestRule.setContent {
            DevTheme {
                Box(
                    Modifier
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 16.dp)
                ) {
                    AccessibilityModule(
                        systemFontScale = 1.3f,
                        useSystemFontScale = true,
                        onUseSystemFontScaleChanged = {},
                        fontScale = 1f,
                        onFontScaleChanged = {},
                    )
                }
            }
        }

        composeTestRule.onRoot()
            .captureRoboImage("src/test/screenshots/AccessibilityModule_system.png")
    }

    @Test
    fun manualFontScale() {
        composeTestRule.setContent {
            DevTheme {
                Box(
                    Modifier
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 16.dp)
                ) {
                    AccessibilityModule(
                        systemFontScale = 1.3f,
                        useSystemFontScale = false,
                        onUseSystemFontScaleChanged = {},
                        fontScale = 1.5f,
                        onFontScaleChanged = {},
                    )
                }
            }
        }

        composeTestRule.onRoot()
            .captureRoboImage("src/test/screenshots/AccessibilityModule_manual.png")
    }
}
