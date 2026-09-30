package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.LogEntry
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.appswithlove.debug.ui.theme.DevTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = RobolectricDeviceQualifiers.Pixel7)
class LogsModuleScreenshotTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val defaultTimeZone = TimeZone.getDefault()

    @Before
    fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    @After
    fun tearDown() {
        TimeZone.setDefault(defaultTimeZone)
    }

    @Test
    fun list() = capture("src/test/screenshots/LogsModule_list.png")

    @Test
    @Config(fontScale = 2f)
    fun listLargeFont() = capture("src/test/screenshots/LogsModule_list_font200.png")

    private fun capture(path: String) {
        val start = 1_790_000_000_000L
        val logHistory = LogHistory().apply {
            push(LogEntry(DevLogSeverity.DEBUG, "Loaded 12 items from cache", timestamp = start))
            push(LogEntry(DevLogSeverity.INFO, "GET https://api.example.com/v1/items 200 (87 ms)", timestamp = start + 1_250, tag = "HTTP"))
            push(LogEntry(DevLogSeverity.WARN, "Image cache is 92% full", timestamp = start + 2_500))
            push(LogEntry(DevLogSeverity.ERROR, "Checkout failed: payment declined", timestamp = start + 3_750, tag = "Checkout"))
        }
        composeTestRule.setContent {
            DevTheme(darkTheme = false) {
                Box(
                    Modifier
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 16.dp)
                ) {
                    LogsModule(logHistory = logHistory, onEntryLongPress = {}, onMaxLogsChanged = {})
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage(path)
    }
}
