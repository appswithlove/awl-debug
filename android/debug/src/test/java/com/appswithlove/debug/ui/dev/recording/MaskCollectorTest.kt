package com.appswithlove.debug.ui.dev.recording

import android.text.InputType
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class MaskCollectorTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun passwordFieldsAndMarkedViewsAreMasked_otherViewsAreNot() {
        val activity = composeRule.activity
        composeRule.runOnUiThread {
            val marked = FrameLayout(activity).apply {
                awlDebugMasked = true
                addView(EditText(activity).apply { inputType = PASSWORD })
            }
            activity.setContentView(
                LinearLayout(activity).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(EditText(activity).apply { inputType = PASSWORD }, 200, 50)
                    addView(EditText(activity).apply { inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD }, 200, 50)
                    addView(EditText(activity).apply { inputType = InputType.TYPE_CLASS_TEXT }, 200, 50)
                    addView(marked, 200, 50)
                    addView(EditText(activity).apply { inputType = PASSWORD; visibility = View.GONE }, 200, 50)
                },
            )
        }
        composeRule.waitForIdle()

        val masks = collectMaskRects(activity.window.decorView)

        // Two password fields and the marked container, whose password child is covered by it.
        masks shouldHaveSize 3
        masks.map { it.width() to it.height() }.distinct() shouldBe listOf(200 to 50)
    }

    @Test
    fun composePasswordFieldAndMarkedComposableAreMasked() {
        composeRule.setContent {
            Column {
                BasicTextField(value = "secret", onValueChange = {}, visualTransformation = PasswordVisualTransformation())
                BasicTextField(value = "visible", onValueChange = {})
                Box(modifier = Modifier.size(40.dp).awlDebugMasked())
            }
        }
        composeRule.waitForIdle()

        val masks = collectMaskRects(composeRule.activity.window.decorView)

        masks shouldHaveSize 2
    }

    @Test
    fun composeInsideViewHierarchyIsSearched() {
        val activity = composeRule.activity
        composeRule.runOnUiThread {
            activity.setContentView(
                FrameLayout(activity).apply {
                    addView(
                        ComposeView(activity).apply { setContent { Box(modifier = Modifier.size(20.dp).awlDebugMasked()) } },
                        ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
                    )
                },
            )
        }
        composeRule.waitForIdle()

        collectMaskRects(activity.window.decorView) shouldHaveSize 1
    }

    private companion object {
        const val PASSWORD = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
    }
}
