package com.appswithlove.debug.ui.dev.recording

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import java.io.ByteArrayOutputStream
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.roundToInt

/**
 * `frames.jpg`: up to [MAX_TILES] frames in [COLUMNS] columns, each tile [TILE_WIDTH] px wide with its capture time
 * (`HH:mm:ss.SSS`) at the bottom left. Blocking, call it off the main thread.
 */
internal object ContactSheet {
    const val COLUMNS = 4
    const val TILE_WIDTH = 270
    const val MAX_TILES = 60
    const val MAX_BYTES = 5 * 1024 * 1024
    private const val QUALITY = 70
    private const val MIN_QUALITY = 30
    private const val LABEL_TEXT_SIZE = 16f
    private const val LABEL_PADDING = 4f

    /** Indices of at most [maxTiles] frames out of [count], evenly spread, first and last always included. */
    fun pickFrames(count: Int, maxTiles: Int = MAX_TILES): List<Int> = when {
        count <= maxTiles -> (0 until count).toList()
        else -> (0 until maxTiles).map { (it * (count - 1).toDouble() / (maxTiles - 1)).roundToInt() }.distinct()
    }

    /** Writes the sheet for [frames] (capture time → JPEG) to [output]. Returns false when no frame was readable. */
    fun write(frames: List<Pair<Long, File>>, output: File, timeZone: TimeZone = TimeZone.getDefault()): Boolean {
        val picked = pickFrames(frames.size).map { frames[it] }
        val firstSize = picked.firstNotNullOfOrNull { frameSize(it.second) } ?: return false
        val tileHeight = (TILE_WIDTH.toFloat() * firstSize.height / firstSize.width).roundToInt()
        val rows = (picked.size + COLUMNS - 1) / COLUMNS
        val sheet = Bitmap.createBitmap(COLUMNS * TILE_WIDTH, rows * tileHeight, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(sheet)
            canvas.drawColor(Color.BLACK)
            val time = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).apply { this.timeZone = timeZone }
            picked.forEachIndexed { index, (timeMillis, file) ->
                val left = index % COLUMNS * TILE_WIDTH
                val top = index / COLUMNS * tileHeight
                decodeScaled(file, tileHeight)?.let { bitmap ->
                    val target = fitInside(bitmap.width, bitmap.height, TILE_WIDTH, tileHeight).apply { offset(left, top) }
                    canvas.drawBitmap(bitmap, null, target, bitmapPaint)
                    bitmap.recycle()
                }
                drawLabel(canvas, time.format(Date(timeMillis)), left.toFloat(), (top + tileHeight).toFloat())
            }
            output.writeBytes(compress(sheet))
            return true
        } finally {
            sheet.recycle()
        }
    }

    /** JPEG at [QUALITY], lower quality only if that is above [MAX_BYTES]. */
    private fun compress(sheet: Bitmap): ByteArray {
        var quality = QUALITY
        while (true) {
            val bytes = ByteArrayOutputStream().also { sheet.compress(Bitmap.CompressFormat.JPEG, quality, it) }.toByteArray()
            if (bytes.size <= MAX_BYTES || quality <= MIN_QUALITY) return bytes
            quality -= 10
        }
    }

    private fun drawLabel(canvas: Canvas, label: String, left: Float, bottom: Float) {
        val bounds = Rect().also { labelPaint.getTextBounds(label, 0, label.length, it) }
        val height = bounds.height() + 2 * LABEL_PADDING
        canvas.drawRect(left, bottom - height, left + bounds.width() + 2 * LABEL_PADDING, bottom, labelBackgroundPaint)
        canvas.drawText(label, left + LABEL_PADDING, bottom - LABEL_PADDING, labelPaint)
    }

    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val labelBackgroundPaint = Paint().apply { color = 0xB3000000.toInt() }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = LABEL_TEXT_SIZE
    }
}
