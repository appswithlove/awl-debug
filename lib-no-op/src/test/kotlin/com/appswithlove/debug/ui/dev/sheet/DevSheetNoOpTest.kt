package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.api.DevModulesConfig
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevSheetNoOpTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun devSheet_inNoOp_rendersContentOnly() {
        composeTestRule.setContent {
            DevSheet(
                devConfig = DevConfig.Preview,
                modulesConfig = DevModulesConfig(),
            ) {
                Box(Modifier.fillMaxSize().testTag("app-content"))
            }
        }

        composeTestRule.onNodeWithTag("app-content").assertIsDisplayed()
    }
}
