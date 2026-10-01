package com.appswithlove.debug.ui.dev.recording

import com.appswithlove.debug.api.extension.DevRecordingExport
import com.appswithlove.debug.api.extension.DevRecordingExportOptions
import com.appswithlove.debug.ui.dev.recording.RecordingBuffer.Companion.frameTimeMillis
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** `recording.mp4` with its optional contact sheet and timeline. */
internal data class RecordingFiles(val video: File, val frames: File?, val timeline: File?)

/**
 * Turns the frames of a recording folder into `recording.mp4`, `frames.jpg` and `timeline.md`, either all frames as a
 * ZIP to share or as files within the limits a caller sets. Blocking, call it off the main thread.
 */
internal object RecordingExporter {
    const val FPS = 3
    const val MAX_VIDEO_LONG_EDGE = 1280
    const val VIDEO_FILE = "recording.mp4"
    const val FRAMES_FILE = "frames.jpg"
    const val TIMELINE_FILE = "timeline.md"

    /**
     * Writes `awl-debug-recording-<yyyy-MM-dd_HH.mm.ss>.zip` with all frames of [recordingDir] into [exportDir],
     * replacing earlier exports there. Returns `null` when the recording has no readable frame.
     */
    fun exportZip(recordingDir: File, exportDir: File, nowMillis: Long = System.currentTimeMillis()): File? {
        exportDir.deleteRecursively()
        val workDir = File(exportDir, "work").apply { mkdirs() }
        val files = writeFiles(RecordingBuffer.frameFiles(recordingDir), recordingDir, workDir, MAX_VIDEO_LONG_EDGE)
            ?: return null.also { workDir.deleteRecursively() }
        val stamp = SimpleDateFormat("yyyy-MM-dd_HH.mm.ss", Locale.US).format(Date(nowMillis))
        val zip = File(exportDir, "awl-debug-recording-$stamp.zip")
        ZipOutputStream(zip.outputStream().buffered()).use { out ->
            listOfNotNull(files.video, files.frames, files.timeline).forEach { file ->
                out.putNextEntry(ZipEntry(file.name))
                file.inputStream().use { it.copyTo(out) }
                out.closeEntry()
            }
        }
        workDir.deleteRecursively()
        return zip
    }

    /**
     * Writes the frames of [recordingDir] within [options] into [outputDir], replacing earlier files there. A video
     * above `maxVideoBytes` is encoded once more at half the size; if it is still too large, all files are `null`.
     * Returns `null` when the recording has no readable frame.
     */
    fun export(recordingDir: File, outputDir: File, options: DevRecordingExportOptions): DevRecordingExport? {
        outputDir.deleteRecursively()
        outputDir.mkdirs()
        val allFrames = RecordingBuffer.frameFiles(recordingDir)
        val frames = options.lastSeconds?.let { seconds -> allFrames.takeLast((seconds * FPS).coerceAtLeast(0)) } ?: allFrames
        val maxVideoBytes = options.maxVideoBytes ?: Long.MAX_VALUE
        val maxTimelineBytes = options.maxTimelineBytes?.toLong() ?: Long.MAX_VALUE
        var longEdge = MAX_VIDEO_LONG_EDGE
        repeat(2) {
            val files = writeFiles(frames, recordingDir, outputDir, longEdge) ?: return null
            if (files.video.length() <= maxVideoBytes) {
                val timeline = files.timeline?.takeIf { it.length() <= maxTimelineBytes }
                if (timeline == null) files.timeline?.delete()
                return DevRecordingExport(video = files.video, frames = files.frames, timeline = timeline)
            }
            longEdge /= 2
        }
        outputDir.deleteRecursively()
        return DevRecordingExport(video = null, frames = null, timeline = null)
    }

    private fun writeFiles(frames: List<File>, recordingDir: File, outputDir: File, maxLongEdge: Int): RecordingFiles? {
        val sized = frames.mapNotNull { file -> frameSize(file)?.let { file to it } }
        val first = sized.firstOrNull()?.second ?: return null
        val video = File(outputDir, VIDEO_FILE)
        val size = Mp4Encoder.videoSize(first.width, first.height, maxLongEdge)
        if (Mp4Encoder.encode(sized.map { it.first }, video, size, FPS) == 0) {
            video.delete()
            return null
        }

        val sheet = File(outputDir, FRAMES_FILE)
        val hasSheet = ContactSheet.write(sized.map { (file, _) -> file.frameTimeMillis() to file }, sheet)

        val events = File(recordingDir, RecordingBuffer.EVENTS_FILE)
        val touches = if (events.exists()) parseTouchEvents(events.readLines()) else emptyList()
        val timelineFrames = sized.map { (file, frameSize) -> TimelineFrame(file.frameTimeMillis(), frameSize.width > frameSize.height) }
        val timeline = File(outputDir, TIMELINE_FILE).apply { writeText(recordingTimeline(timelineFrames, touches, FPS)) }

        return RecordingFiles(video = video, frames = sheet.takeIf { hasSheet }, timeline = timeline)
    }
}
