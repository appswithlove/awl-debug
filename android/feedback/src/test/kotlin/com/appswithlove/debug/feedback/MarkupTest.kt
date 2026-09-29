package com.appswithlove.debug.feedback

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.ui.geometry.Offset
import io.kotest.matchers.floats.plusOrMinus
import io.kotest.matchers.shouldBe
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class MarkupTest {

    private val width = 200
    private val height = 400

    @Test
    fun pointsArrowHeadBackFromTip() {
        val (left, right) = arrowHead(start = Offset(0f, 0f), end = Offset(100f, 0f), headLength = 10f)

        left.x shouldBe (100f - 8.660f plusOrMinus 0.01f)
        left.y shouldBe (-5f plusOrMinus 0.01f)
        right.x shouldBe (100f - 8.660f plusOrMinus 0.01f)
        right.y shouldBe (5f plusOrMinus 0.01f)
    }

    @Test
    fun scalesArrowToImageSize() {
        val arrow = Mark.Arrow(start = Offset(0.1f, 0.25f), end = Offset(0.9f, 0.25f), color = MarkupColor.Blue)

        val (shaft, head) = arrow.polylines(width.toFloat(), height.toFloat())

        shaft shouldBe listOf(Offset(20f, 100f), Offset(180f, 100f))
        head[1] shouldBe Offset(180f, 100f)
    }

    @Test
    fun burnsMarksInTheirColors() {
        val screenshot = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.WHITE) }
        val marks = listOf(
            Mark.Stroke(points = listOf(Offset(0.5f, 0.6f), Offset(0.5f, 0.9f)), color = MarkupColor.Red),
            Mark.Arrow(start = Offset(0.1f, 0.25f), end = Offset(0.9f, 0.25f), color = MarkupColor.Blue),
        )

        val burnt = burnMarks(screenshot, marks)

        burnt.getPixel(100, 300) shouldBe MarkupColor.Red.argb
        burnt.getPixel(60, 100) shouldBe MarkupColor.Blue.argb
        burnt.getPixel(10, 10) shouldBe Color.WHITE
    }
}
