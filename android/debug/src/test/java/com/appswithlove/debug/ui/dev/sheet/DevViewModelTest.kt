package com.appswithlove.debug.ui.dev.sheet

import androidx.test.core.app.ApplicationProvider
import app.cash.turbine.test
import com.appswithlove.debug.domain.storage.DevStore
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevViewModelTest {

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun showDevSheet_explicitValue_isAppliedInsteadOfToggling() = runTest {
        val devStore = DevStore(ApplicationProvider.getApplicationContext())
        devStore.setDevToolActivated(true)
        val viewModel = DevViewModel(devStore)

        viewModel.state.test {
            while (!awaitItem().isActive) Unit

            viewModel.submitAction(DevAction.ShowDevSheet(show = true))
            awaitItem().isShown shouldBe true

            viewModel.submitAction(DevAction.ShowDevSheet(show = true))
            expectNoEvents()

            viewModel.submitAction(DevAction.ShowDevSheet(show = false))
            awaitItem().isShown shouldBe false
        }
    }
}
