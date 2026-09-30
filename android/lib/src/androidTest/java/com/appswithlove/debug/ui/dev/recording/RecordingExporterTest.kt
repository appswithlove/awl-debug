package com.appswithlove.debug.ui.dev.recording

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.MediaExtractor
import android.media.MediaFormat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.appswithlove.debug.api.extension.DevRecordingExportOptions
import java.io.File
import java.util.Locale
import java.util.zip.ZipFile
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Encodes real frames with the device's H.264 encoder. */
@RunWith(AndroidJUnit4::class)
class RecordingExporterTest {
    private lateinit var root: File
    private lateinit var recording: File

    @Before
    fun setUp() {
        root = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "recording-exporter-test")
        root.deleteRecursively()
        recording = File(root, "current").apply { mkdirs() }
    }

    @After
    fun tearDown() {
        root.deleteRecursively()
    }

    @Test
    fun exportZip_containsVideoContactSheetAndTimeline() {
        writeFrames(count = 12, width = 1080, height = 2340)
        File(recording, RecordingBuffer.EVENTS_FILE).writeText("1000500\tbegan\t0.5000\t0.2500\n1000600\tended\t0.5000\t0.2500\n")

        val zip = RecordingExporter.exportZip(recording, File(root, "export"), nowMillis = 0L)

        assertNotNull(zip)
        assertTrue(zip!!.name.matches(Regex("awl-debug-recording-\\d{4}-\\d{2}-\\d{2}_\\d{2}\\.\\d{2}\\.\\d{2}\\.zip")))
        val entries = ZipFile(zip).use { file -> file.entries().toList().map { it.name }.sorted() }
        assertEquals(listOf("frames.jpg", "recording.mp4", "timeline.md"), entries)
    }

    @Test
    fun export_keepsTheLastSecondsWithinTheLimits() {
        writeFrames(count = 200, width = 1080, height = 2340)

        val export = RecordingExporter.export(recording, File(root, "export"), limits)

        val video = export!!.video!!
        assertEquals("ftyp", String(video.readBytes().copyOfRange(4, 8), Charsets.US_ASCII))
        assertTrue(video.length() <= limits.maxVideoBytes!!)
        val format = videoFormat(video)
        val width = format.getInteger(MediaFormat.KEY_WIDTH)
        val height = format.getInteger(MediaFormat.KEY_HEIGHT)
        assertEquals(MediaFormat.MIMETYPE_VIDEO_AVC, format.getString(MediaFormat.KEY_MIME))
        assertTrue("$width x $height", maxOf(width, height) <= 1280 && width % 2 == 0 && height % 2 == 0)
        assertEquals(180, sampleCount(video))

        val sheet = BitmapFactory.decodeFile(export.frames!!.path)
        assertEquals(4 * 270, sheet.width)
        assertTrue(export.frames!!.length() <= 5 * 1024 * 1024)
        val timeline = export.timeline!!.readText()
        assertTrue(timeline, timeline.contains("· frames: 180 · fps: 3"))
    }

    @Test
    fun export_tooLargeVideo_isEncodedAgainAtHalfSize() {
        writeFrames(count = 30, width = 1080, height = 2340)
        val fullSize = RecordingExporter.export(recording, File(root, "full"), DevRecordingExportOptions())!!.video!!.length()

        val export = RecordingExporter.export(recording, File(root, "export"), DevRecordingExportOptions(maxVideoBytes = fullSize - 1))

        val video = export!!.video!!
        assertTrue(video.length() < fullSize)
        val format = videoFormat(video)
        assertTrue(maxOf(format.getInteger(MediaFormat.KEY_WIDTH), format.getInteger(MediaFormat.KEY_HEIGHT)) <= 640)
        assertNotNull(export.frames)
        assertNotNull(export.timeline)
    }

    @Test
    fun export_videoStillTooLargeAtHalfSize_returnsNoFiles() {
        writeFrames(count = 30, width = 1080, height = 2340)
        val output = File(root, "export")

        val export = RecordingExporter.export(recording, output, DevRecordingExportOptions(maxVideoBytes = 1))

        assertNotNull(export)
        assertNull(export!!.video)
        assertNull(export.frames)
        assertNull(export.timeline)
        assertTrue(output.listFiles().isNullOrEmpty())
    }

    @Test
    fun export_tooLargeTimeline_isLeftOut() {
        writeFrames(count = 12, width = 1080, height = 2340)

        val export = RecordingExporter.export(recording, File(root, "export"), DevRecordingExportOptions(maxTimelineBytes = 1))

        assertNotNull(export!!.video)
        assertNull(export.timeline)
    }

    @Test
    fun export_withoutFrames_returnsNull() {
        assertNull(RecordingExporter.export(recording, File(root, "export"), limits))
    }

    private val limits = DevRecordingExportOptions(lastSeconds = 60, maxVideoBytes = 25L * 1024 * 1024, maxTimelineBytes = 256 * 1024)

    private fun writeFrames(count: Int, width: Int, height: Int) {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        repeat(count) { index ->
            bitmap.eraseColor(Color.rgb(index * 7 % 256, 80, 255 - index % 256))
            val name = String.format(Locale.ROOT, "%013d.jpg", 1_000_000L + index * 333L)
            File(recording, name).outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 60, it) }
        }
        bitmap.recycle()
    }

    private fun videoFormat(file: File): MediaFormat = withVideoTrack(file) { it.getTrackFormat(it.sampleTrackIndex) }

    private fun sampleCount(file: File): Int = withVideoTrack(file) { extractor ->
        var count = 0
        while (extractor.sampleTrackIndex >= 0) {
            count++
            extractor.advance()
        }
        count
    }

    private fun <T> withVideoTrack(file: File, block: (MediaExtractor) -> T): T {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(file.path)
            assertEquals(1, extractor.trackCount)
            extractor.selectTrack(0)
            return block(extractor)
        } finally {
            extractor.release()
        }
    }
}
