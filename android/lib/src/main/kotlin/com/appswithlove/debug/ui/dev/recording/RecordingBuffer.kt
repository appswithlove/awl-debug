package com.appswithlove.debug.ui.dev.recording

import android.graphics.Bitmap
import java.io.File
import java.util.Locale

/** Frames of a recording on disk, oldest first. */
internal data class RecordingInfo(
    val directory: File,
    val frameCount: Int,
    val startedAtMillis: Long,
    val endedAtMillis: Long,
)

/**
 * Ring buffer of JPEG frames in `<root>/current`. Each frame is a file named by its capture time, so it
 * survives a crash; [rotate] moves the previous run's frames to `<root>/last`. Touch starts and ends go
 * to `events.tsv` as `<time ms>\t<began|ended>\t<x 0–1>\t<y 0–1>`. Not thread-safe: use one thread.
 */
internal class RecordingBuffer(private val root: File) {
    val currentDir = File(root, "current")
    val lastDir = File(root, "last")
    private val frames = ArrayDeque<File>()

    val frameCount: Int get() = frames.size

    /** Call once per process start, before the first [writeFrame]. */
    fun rotate() {
        if (frameFiles(currentDir).isNotEmpty()) {
            lastDir.deleteRecursively()
            if (!currentDir.renameTo(lastDir)) currentDir.deleteRecursively()
        } else {
            currentDir.deleteRecursively()
        }
        currentDir.mkdirs()
        frames.clear()
    }

    fun writeFrame(timeMillis: Long, bitmap: Bitmap, quality: Int) {
        val name = String.format(Locale.ROOT, "%013d", timeMillis)
        val temp = File(currentDir, "$name.tmp")
        temp.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        val frame = File(currentDir, "$name$FRAME_SUFFIX")
        if (temp.renameTo(frame)) frames.addLast(frame) else temp.delete()
    }

    fun appendEvents(lines: List<String>) {
        if (lines.isEmpty()) return
        File(currentDir, EVENTS_FILE).appendText(lines.joinToString(separator = "\n", postfix = "\n"))
    }

    /** Deletes the oldest frames until at most [maxFrames] are left. */
    fun trim(maxFrames: Int) {
        while (frames.size > maxFrames) frames.removeFirst().delete()
    }

    fun lastRecording(): RecordingInfo? = info(lastDir)

    fun currentRecording(): RecordingInfo? = info(currentDir)

    private fun info(directory: File): RecordingInfo? {
        val files = frameFiles(directory).ifEmpty { return null }
        return RecordingInfo(
            directory = directory,
            frameCount = files.size,
            startedAtMillis = files.first().frameTimeMillis(),
            endedAtMillis = files.last().frameTimeMillis(),
        )
    }

    companion object {
        const val FRAME_SUFFIX = ".jpg"
        const val EVENTS_FILE = "events.tsv"

        /** Frames of [directory] in capture order. */
        fun frameFiles(directory: File): List<File> =
            directory.listFiles { file -> file.name.endsWith(FRAME_SUFFIX) }.orEmpty().sortedBy { it.name }

        fun File.frameTimeMillis(): Long = name.removeSuffix(FRAME_SUFFIX).toLongOrNull() ?: lastModified()
    }
}
