package com.appswithlove.debug.ui.dev.sheet.modules.network

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.dev.network.CapturedBody
import com.appswithlove.debug.ui.dev.network.NetworkFilter
import com.appswithlove.debug.ui.dev.network.NetworkUiState
import com.appswithlove.debug.ui.dev.network.networkEntry
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
class NetworkModuleScreenshotTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val defaultTimeZone = TimeZone.getDefault()

    private val entries = listOf(
        networkEntry(id = 6, method = "GET", status = 0, url = "https://api.example.com/v1/profile", error = "java.net.SocketTimeoutException: timeout"),
        networkEntry(id = 5, method = "DELETE", status = 500, url = "https://api.example.com/v1/items/7"),
        networkEntry(id = 4, method = "POST", status = 422, url = "https://api.example.com/v1/items"),
        networkEntry(id = 3, method = "GET", status = 304, url = "https://cdn.example.com/images/logo.png"),
        networkEntry(id = 2, method = "GET", status = 200, durationMs = 2_340, url = "https://api.example.com/v1/items?page=2"),
        networkEntry(id = 1, method = "PUT", status = 204, url = "https://api.example.com/v1/settings"),
    )

    @Before
    fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    @After
    fun tearDown() {
        TimeZone.setDefault(defaultTimeZone)
    }

    @Test
    fun list() {
        capture("src/test/screenshots/NetworkModule_list.png") {
            NetworkModule(
                state = NetworkUiState(entries = entries, methods = listOf("DELETE", "GET", "POST", "PUT")),
                onSearch = {},
                onEntryClick = {},
                onShowFilters = {},
                onSortChanged = {},
                onClear = {},
                onExport = {},
                onMaxSizeChanged = {},
            )
        }
    }

    @Test
    @Config(fontScale = 2f)
    fun listLargeFont() {
        capture("src/test/screenshots/NetworkModule_list_font200.png") {
            NetworkModule(
                state = NetworkUiState(entries = entries.take(3), methods = listOf("DELETE", "GET", "POST", "PUT")),
                onSearch = {},
                onEntryClick = {},
                onShowFilters = {},
                onSortChanged = {},
                onClear = {},
                onExport = {},
                onMaxSizeChanged = {},
            )
        }
    }

    @Test
    @Config(fontScale = 2f)
    fun filtersLargeFont() {
        capture("src/test/screenshots/NetworkModule_filters_font200.png") {
            NetworkFiltersModule(
                state = NetworkUiState(
                    entries = entries,
                    methods = listOf("GET", "POST"),
                    hosts = listOf("api.example.com"),
                    filter = NetworkFilter(excludedMethods = setOf("POST")),
                ),
                onExcludedMethodsChanged = {},
                onExcludedStatusClassesChanged = {},
                onExcludedHostsChanged = {},
                onDone = {},
            )
        }
    }

    @Test
    fun detail() {
        val entry = networkEntry(
            method = "POST",
            status = 201,
            url = "https://api.example.com/v1/login?token=[REDACTED]",
            requestHeaders = listOf("Authorization" to "[REDACTED]", "Accept" to "application/json"),
            requestBody = CapturedBody("""{"email":"test@example.com","password":"[REDACTED]"}""", "application/json", originalBytes = 48),
            responseHeaders = listOf("Content-Type" to "application/json", "Set-Cookie" to "[REDACTED]"),
            responseBody = CapturedBody("""{"accessToken":"[REDACTED]","expiresIn":3600}""", "application/json", originalBytes = 44),
            redactedCount = 5,
        )
        capture("src/test/screenshots/NetworkModule_detail.png") {
            NetworkDetailModule(entry = entry, onCopy = {}, onShare = {})
        }
    }

    private fun capture(path: String, content: @Composable () -> Unit) {
        composeTestRule.setContent {
            DevTheme(darkTheme = false) {
                Box(
                    Modifier
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 16.dp)
                ) {
                    content()
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage(path)
    }
}
