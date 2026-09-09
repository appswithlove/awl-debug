package com.appswithlove.debug.domain.model

import app.cash.turbine.test
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DevSettingsNoOpTest {

    private val context = RuntimeEnvironment.getApplication()

    @Test
    fun isDevToolActivated_inNoOp_alwaysEmitsFalse() = runTest {
        DevSettings.isDevToolActivated(context).test {
            awaitItem() shouldBe false
            awaitComplete()
        }
    }

    @Test
    fun activateDevTool_inNoOp_isInertAndKeepsToolDisabled() = runTest {
        DevSettings.activateDevTool(context, activate = true)

        DevSettings.isDevToolActivated(context).test {
            awaitItem() shouldBe false
            awaitComplete()
        }
    }
}
