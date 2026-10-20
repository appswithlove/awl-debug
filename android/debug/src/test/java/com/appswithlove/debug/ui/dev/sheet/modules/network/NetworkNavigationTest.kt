package com.appswithlove.debug.ui.dev.sheet.modules.network

import androidx.compose.material3.Text
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.api.DevNetworkConfig
import com.appswithlove.debug.domain.storage.DevStore
import com.appswithlove.debug.ui.dev.log.DevHttpLogInterceptor
import com.appswithlove.debug.ui.dev.log.LogCollector
import com.appswithlove.debug.ui.dev.network.NetworkCollector
import com.appswithlove.debug.ui.dev.network.networkEntry
import com.appswithlove.debug.ui.dev.sheet.DevAction
import com.appswithlove.debug.ui.dev.sheet.DevSheet
import com.appswithlove.debug.ui.dev.sheet.DevViewModel
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NetworkNavigationTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun network_fromHomeToListToDetail() {
        val store = NetworkCollector.store
        DevHttpLogInterceptor(DevNetworkConfig(), store, LogCollector.devLogCollector)
        store.clear()
        store.add(networkEntry(id = store.newId(), method = "POST", url = "https://api.example.com/v1/items"))
        val devStore = DevStore(ApplicationProvider.getApplicationContext())
        runBlocking { devStore.setDevToolActivated(true) }
        val viewModel = DevViewModel(devStore)

        composeTestRule.setContent {
            DevSheet(viewModel = viewModel, logHistory = LogCollector.logHistory) { Text("App") }
        }
        composeTestRule.waitUntil(5_000) { viewModel.state.value.isActive }
        viewModel.submitAction(DevAction.ShowDevSheet(show = true))

        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("Network")).fetchSemanticsNodes().isNotEmpty()
        }
        // Touch injection does not reach the bottom sheet window under Robolectric, so click via semantics.
        composeTestRule.onNode(hasText("Network") and hasClickAction())
            .performSemanticsAction(SemanticsActions.OnClick)
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("api.example.com/v1/items")).fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithText("Number of requests: 1 / 750").assertExists()
        composeTestRule.onNode(hasText("api.example.com/v1/items") and hasClickAction())
            .performSemanticsAction(SemanticsActions.OnClick)
        composeTestRule.waitUntil(5_000) {
            composeTestRule.onAllNodes(hasText("Copy cURL")).fetchSemanticsNodes().isNotEmpty()
        }
        composeTestRule.onNodeWithText("Response Body").assertExists()
    }
}
