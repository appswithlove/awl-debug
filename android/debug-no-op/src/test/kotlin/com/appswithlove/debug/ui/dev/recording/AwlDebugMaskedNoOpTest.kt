package com.appswithlove.debug.ui.dev.recording

import android.view.View
import androidx.compose.ui.Modifier
import androidx.test.core.app.ApplicationProvider
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeSameInstanceAs
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AwlDebugMaskedNoOpTest {

    @Test
    fun markersHaveNoEffect() {
        val view = View(ApplicationProvider.getApplicationContext())

        view.awlDebugMasked = true

        view.awlDebugMasked shouldBe false
        view.tag shouldBe null
        Modifier.awlDebugMasked() shouldBeSameInstanceAs Modifier
    }
}
