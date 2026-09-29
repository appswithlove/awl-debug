package com.appswithlove.debug.feedback

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import androidx.annotation.StringRes
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import java.io.ByteArrayOutputStream
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/** Line width relative to the image width, so marks look the same on screen and in the upload. */
internal const val STROKE_WIDTH_FRACTION = 0.012f
private const val ARROW_HEAD_FRACTION = 0.05f
private const val ARROW_HEAD_ANGLE = PI / 6

private const val MAX_UPLOAD_BYTES = 5 * 1024 * 1024
private const val JPEG_QUALITY = 85
private const val DOWNSCALE_STEP = 0.75f

internal enum class MarkupTool { Pen, Arrow, Redact }

internal enum class MarkupColor(val argb: Int, @param:StringRes val label: Int) {
    Red(0xFFE53935.toInt(), R.string.feedback_color_red),
    Yellow(0xFFFDD835.toInt(), R.string.feedback_color_yellow),
    Green(0xFF43A047.toInt(), R.string.feedback_color_green),
    Blue(0xFF1E88E5.toInt(), R.string.feedback_color_blue),
    Black(0xFF000000.toInt(), R.string.feedback_color_black),
}

/** A mark on the screenshot; all points are fractions (0..1) of the image's width and height. */
internal sealed interface Mark {
    val color: MarkupColor

    data class Stroke(val points: List<Offset>, override val color: MarkupColor) : Mark
    data class Arrow(val start: Offset, val end: Offset, override val color: MarkupColor) : Mark

    /** A rectangle between two corners, filled black so the area never leaves the device. */
    data class Redact(val start: Offset, val end: Offset) : Mark {
        override val color: MarkupColor get() = MarkupColor.Black
    }
}

/** The redacted area in pixels of a [width] x [height] image. */
internal fun Mark.Redact.rect(width: Float, height: Float): Rect = Rect(
    left = minOf(start.x, end.x) * width,
    top = minOf(start.y, end.y) * height,
    right = maxOf(start.x, end.x) * width,
    bottom = maxOf(start.y, end.y) * height,
)

/** The mark as open polylines in pixels of a [width] x [height] image; shared by the screen and the burn-in. */
internal fun Mark.polylines(width: Float, height: Float): List<List<Offset>> {
    fun Offset.scaled() = Offset(x * width, y * height)
    return when (this) {
        is Mark.Stroke -> listOf(points.map { it.scaled() })
        is Mark.Arrow -> {
            val tip = end.scaled()
            val (left, right) = arrowHead(start.scaled(), tip, headLength = ARROW_HEAD_FRACTION * width)
            listOf(listOf(start.scaled(), tip), listOf(left, tip, right))
        }
        is Mark.Redact -> emptyList()
    }
}

/** The two barb ends of an arrow pointing from [start] to [end]. */
internal fun arrowHead(start: Offset, end: Offset, headLength: Float): Pair<Offset, Offset> {
    val angle = atan2((end.y - start.y).toDouble(), (end.x - start.x).toDouble())
    fun barb(side: Double) = Offset(
        (end.x - headLength * cos(angle + side)).toFloat(),
        (end.y - headLength * sin(angle + side)).toFloat(),
    )
    return barb(ARROW_HEAD_ANGLE) to barb(-ARROW_HEAD_ANGLE)
}

/** Burns [marks] into a copy of [screenshot] and encodes it as JPEG within the service's size limit. */
internal fun encodeMarkedScreenshot(screenshot: Bitmap, marks: List<Mark>): EncodedImage {
    var image = burnMarks(screenshot, marks)
    while (true) {
        val bytes = ByteArrayOutputStream().use { out ->
            image.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            out.toByteArray()
        }
        if (bytes.size <= MAX_UPLOAD_BYTES || image.width < 2) {
            return EncodedImage(bytes = bytes, mimeType = "image/jpeg", fileName = "screenshot.jpg")
        }
        image = Bitmap.createScaledBitmap(image, (image.width * DOWNSCALE_STEP).toInt(), (image.height * DOWNSCALE_STEP).toInt(), true)
    }
}

internal fun burnMarks(screenshot: Bitmap, marks: List<Mark>): Bitmap {
    // A software copy: the captured bitmap may be a hardware bitmap, which a software canvas cannot draw.
    val source = screenshot.copy(Bitmap.Config.ARGB_8888, false)
    val result = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(result)
    // JPEG has no alpha; transparent regions would otherwise turn black.
    canvas.drawColor(Color.WHITE)
    canvas.drawBitmap(source, 0f, 0f, null)
    val width = result.width.toFloat()
    val height = result.height.toFloat()
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = STROKE_WIDTH_FRACTION * width
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    val fill = Paint().apply {
        style = Paint.Style.FILL
        color = MarkupColor.Black.argb
    }
    marks.forEach { mark ->
        if (mark is Mark.Redact) {
            val area = mark.rect(width, height)
            canvas.drawRect(area.left, area.top, area.right, area.bottom, fill)
            return@forEach
        }
        paint.color = mark.color.argb
        mark.polylines(width, height).filter { it.isNotEmpty() }.forEach { line ->
            val path = Path()
            path.moveTo(line.first().x, line.first().y)
            line.drop(1).forEach { point -> path.lineTo(point.x, point.y) }
            // A single tap still leaves a visible dot.
            if (line.size == 1) path.lineTo(line.first().x + 0.1f, line.first().y)
            canvas.drawPath(path, paint)
        }
    }
    return result
}
