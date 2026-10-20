package com.appswithlove.debug.ui.dev.recording

import android.graphics.Bitmap
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.shouldBe
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RecordingBufferTest {

    @get:Rule
    val folder = TemporaryFolder()

    private val bitmap = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888)

    @Test
    fun trim_keepsTheNewestFrames() {
        val buffer = RecordingBuffer(folder.root).apply { rotate() }

        (1L..5L).forEach { buffer.writeFrame(it, bitmap, 60) }
        buffer.trim(maxFrames = 3)

        RecordingBuffer.frameFiles(buffer.currentDir).map { it.name } shouldBe
            listOf("0000000000003.jpg", "0000000000004.jpg", "0000000000005.jpg")
    }

    @Test
    fun rotate_movesFramesOfThePreviousRunToLast() {
        RecordingBuffer(folder.root).apply {
            rotate()
            writeFrame(1_000L, bitmap, 60)
            writeFrame(2_000L, bitmap, 60)
            appendEvents(listOf("1000\tbegan\t0.5000\t0.5000"))
        }

        val restarted = RecordingBuffer(folder.root).apply { rotate() }

        restarted.lastRecording() shouldBe RecordingInfo(restarted.lastDir, 2, 1_000L, 2_000L)
        restarted.lastDir.resolve(RecordingBuffer.EVENTS_FILE).exists() shouldBe true
        restarted.currentRecording().shouldBeNull()
    }

    @Test
    fun rotate_withoutNewFrames_keepsTheLastRecording() {
        RecordingBuffer(folder.root).apply {
            rotate()
            writeFrame(1_000L, bitmap, 60)
        }
        RecordingBuffer(folder.root).rotate()

        val restarted = RecordingBuffer(folder.root).apply { rotate() }

        restarted.lastRecording()?.frameCount shouldBe 1
    }
}
