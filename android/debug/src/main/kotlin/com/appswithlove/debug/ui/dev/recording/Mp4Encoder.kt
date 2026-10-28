package com.appswithlove.debug.ui.dev.recording

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Size
import java.io.File
import kotlin.math.max
import kotlin.math.min

/**
 * Encodes JPEG frames into an H.264 MP4 with a fixed frame rate, one video frame per recorded frame (the time axis
 * is compressed). Frames of another orientation are letterboxed. Blocking, call it off the main thread.
 */
internal object Mp4Encoder {
    private const val TIMEOUT_US = 10_000L
    private const val I_FRAME_INTERVAL_SECONDS = 10
    private const val BITS_PER_PIXEL = 0.5f

    /** Size of a video for frames of [frameWidth] × [frameHeight]: long edge at most [maxLongEdge], multiples of 16. */
    fun videoSize(frameWidth: Int, frameHeight: Int, maxLongEdge: Int): Size {
        val scale = min(1f, maxLongEdge.toFloat() / max(frameWidth, frameHeight))
        fun align(value: Float) = max(16, value.toInt() / 16 * 16)
        return Size(align(frameWidth * scale), align(frameHeight * scale))
    }

    /** Writes [frames] to [output]; unreadable frames are skipped. Returns the number of encoded frames. */
    fun encode(frames: List<File>, output: File, size: Size, fps: Int): Int {
        val width = size.width
        val height = size.height
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, (width * height * fps * BITS_PER_PIXEL).toInt())
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL_SECONDS)
        }
        output.delete()
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        val canvasBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val canvas = Canvas(canvasBitmap)
            val pixels = IntArray(width * height)
            val sources = frames.iterator()
            val info = MediaCodec.BufferInfo()
            var track = -1
            var encoded = 0
            var inputDone = false
            var outputDone = false
            while (!outputDone) {
                if (!inputDone) {
                    val index = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (index >= 0) {
                        val presentationUs = encoded * 1_000_000L / fps
                        val bitmap = nextFrame(sources, width, height)
                        if (bitmap == null) {
                            codec.queueInputBuffer(index, 0, 0, presentationUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            drawLetterboxed(canvas, bitmap, width, height)
                            bitmap.recycle()
                            canvasBitmap.getPixels(pixels, 0, width, 0, 0, width, height)
                            val image = checkNotNull(codec.getInputImage(index)) { "Encoder has no input image" }
                            writeYuv(image, pixels, width, height)
                            codec.queueInputBuffer(index, 0, width * height * 3 / 2, presentationUs, 0)
                            encoded++
                        }
                    }
                }
                while (true) {
                    val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                    if (index == MediaCodec.INFO_TRY_AGAIN_LATER) break
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                        continue
                    }
                    if (index < 0) continue
                    val buffer = checkNotNull(codec.getOutputBuffer(index))
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!isConfig && info.size > 0 && muxerStarted) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                        break
                    }
                }
            }
            return encoded
        } finally {
            canvasBitmap.recycle()
            runCatching { codec.stop() }
            codec.release()
            if (muxerStarted) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
        }
    }

    /** Decodes the next readable frame, downsampled close to the video size. */
    private fun nextFrame(sources: Iterator<File>, width: Int, height: Int): Bitmap? {
        while (sources.hasNext()) {
            decodeScaled(sources.next(), max(width, height))?.let { return it }
        }
        return null
    }

    private fun drawLetterboxed(canvas: Canvas, bitmap: Bitmap, width: Int, height: Int) {
        canvas.drawColor(Color.BLACK)
        canvas.drawBitmap(bitmap, null, fitInside(bitmap.width, bitmap.height, width, height), bitmapPaint)
    }

    /** BT.601 limited range, chroma from the top left pixel of each 2 × 2 block. */
    private fun writeYuv(image: Image, pixels: IntArray, width: Int, height: Int) {
        val (yPlane, uPlane, vPlane) = image.planes
        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val yRowBytes = ByteArray(width)
        for (row in 0 until height) {
            val pixelRow = row * width
            val isChromaRow = row % 2 == 0
            for (column in 0 until width) {
                val color = pixels[pixelRow + column]
                val r = color shr 16 and 0xFF
                val g = color shr 8 and 0xFF
                val b = color and 0xFF
                yRowBytes[column] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
                if (isChromaRow && column % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    uBuffer.put(row / 2 * uPlane.rowStride + column / 2 * uPlane.pixelStride, u.toByte())
                    vBuffer.put(row / 2 * vPlane.rowStride + column / 2 * vPlane.pixelStride, v.toByte())
                }
            }
            if (yPlane.pixelStride == 1) {
                yBuffer.position(row * yPlane.rowStride)
                yBuffer.put(yRowBytes)
            } else {
                for (column in 0 until width) yBuffer.put(row * yPlane.rowStride + column * yPlane.pixelStride, yRowBytes[column])
            }
        }
    }

    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)
}

/** The largest rectangle with the aspect ratio of [sourceWidth] × [sourceHeight] centered in [width] × [height]. */
internal fun fitInside(sourceWidth: Int, sourceHeight: Int, width: Int, height: Int): Rect {
    val scale = min(width.toFloat() / sourceWidth, height.toFloat() / sourceHeight)
    val scaledWidth = (sourceWidth * scale).toInt()
    val scaledHeight = (sourceHeight * scale).toInt()
    val left = (width - scaledWidth) / 2
    val top = (height - scaledHeight) / 2
    return Rect(left, top, left + scaledWidth, top + scaledHeight)
}

/** Decodes [file] with the largest power-of-two downsampling that keeps its long edge at least [minLongEdge]. */
internal fun decodeScaled(file: File, minLongEdge: Int): Bitmap? {
    val bounds = frameSize(file) ?: return null
    var sampleSize = 1
    while (max(bounds.width, bounds.height) / (sampleSize * 2) >= minLongEdge) sampleSize *= 2
    return runCatching {
        BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sampleSize })
    }.getOrNull()
}

/** Pixel size of a JPEG frame without decoding it, `null` when it is missing or broken. */
internal fun frameSize(file: File): Size? {
    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(file.path, options)
    return if (options.outWidth > 0 && options.outHeight > 0) Size(options.outWidth, options.outHeight) else null
}
