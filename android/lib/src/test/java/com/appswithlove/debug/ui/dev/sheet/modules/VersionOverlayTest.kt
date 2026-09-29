package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.clickable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.click
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.domain.storage.DevStore
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class VersionOverlayTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val devConfig = DevConfig(versionName = "2.0.0", versionCode = 42, flavor = "staging", buildType = "debug")

    @Test
    fun overlay_showsVersionAndLetsTouchesThrough() {
        var clicks = 0
        composeTestRule.setContent {
            Box {
                // A rectangular clickable area, unlike a rounded Button, covers the overlay's corner.
                Box(modifier = Modifier.fillMaxSize().clickable { clicks++ })
                VersionOverlay(devConfig = devConfig)
            }
        }

        composeTestRule.onNodeWithText("AWL 2.0.0 (42)").performTouchInput { click(center) }

        clicks shouldBe 1
    }

    @Test
    fun versionOverlayVisible_isStoredPerDevice() = runTest {
        val store = DevStore(ApplicationProvider.getApplicationContext())

        store.setVersionOverlayVisible(false)

        DevStore(ApplicationProvider.getApplicationContext()).versionOverlayVisible.first() shouldBe false
    }
}
