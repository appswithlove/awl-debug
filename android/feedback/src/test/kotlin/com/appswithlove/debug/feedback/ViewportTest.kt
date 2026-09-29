package com.appswithlove.debug.feedback

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import io.kotest.matchers.shouldBe
import org.junit.Test

class ViewportTest {

    private val frame = Size(100f, 200f)
    private val center = Offset(50f, 100f)

    @Test
    fun zoomsAroundPinchCenter() {
        val zoomed = Viewport().transformed(centroid = center, pan = Offset.Zero, zoom = 2f, size = frame)

        zoomed shouldBe Viewport(scale = 2f, offset = Offset(-0.5f, -0.5f))
        zoomed.toContent(center, frame) shouldBe center
    }

    @Test
    fun mapsScreenPointBackToContent() {
        val zoomed = Viewport(scale = 2f, offset = Offset(-0.5f, -0.25f))

        zoomed.toContent(Offset(0f, 0f), frame) shouldBe Offset(25f, 25f)
    }

    @Test
    fun keepsContentCoveringTheFrame() {
        val zoomed = Viewport(scale = 2f, offset = Offset(-0.5f, -0.5f))

        zoomed.transformed(centroid = center, pan = Offset(500f, -500f), zoom = 1f, size = frame) shouldBe Viewport(scale = 2f, offset = Offset(0f, -1f))
        zoomed.transformed(centroid = center, pan = Offset.Zero, zoom = 0.1f, size = frame) shouldBe Viewport()
    }
}
