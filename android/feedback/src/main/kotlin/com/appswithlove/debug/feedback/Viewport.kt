package com.appswithlove.debug.feedback

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size

private const val MAX_SCALE = 5f

/**
 * Zoom and pan of the screenshot: a content point `p` (pixels of a frame of size `s`) is shown at `p * scale + offset * s`.
 * [offset] is a fraction of the frame, so the view survives the frame resizing (e.g. when the keyboard opens).
 * The content always covers the frame, so there is no empty border when zoomed in.
 */
internal data class Viewport(
    val scale: Float = 1f,
    val offset: Offset = Offset.Zero,
) {
    /** Applies a pinch ([zoom] around [centroid]) and a two-finger [pan], both in pixels of a frame of [size]. */
    fun transformed(centroid: Offset, pan: Offset, zoom: Float, size: Size): Viewport {
        if (size.width <= 0f || size.height <= 0f) return this
        val newScale = (scale * zoom).coerceIn(1f, MAX_SCALE)
        val appliedZoom = newScale / scale
        val moved = centroid - (centroid - offset.inPixels(size)) * appliedZoom + pan
        return Viewport(
            scale = newScale,
            offset = Offset(
                moved.x.coerceIn(size.width * (1 - newScale), 0f) / size.width,
                moved.y.coerceIn(size.height * (1 - newScale), 0f) / size.height,
            ),
        )
    }

    /** The content point under the on-screen [point] of a frame of [size]. */
    fun toContent(point: Offset, size: Size): Offset = (point - offset.inPixels(size)) / scale

    fun translation(size: Size): Offset = offset.inPixels(size)

    private fun Offset.inPixels(size: Size) = Offset(x * size.width, y * size.height)
}
