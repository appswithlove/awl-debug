package com.appswithlove.debug.api.extension

import java.io.File

/**
 * Limits for [AwlDebugExtensions.exportRecording]; `null` means no limit.
 *
 * @param lastSeconds Only the newest `lastSeconds × 3` frames. The recording keeps 3 frames per second of activity.
 * @param maxVideoBytes Largest video. A larger one is encoded once more at half the size; when that is still too
 * large, no files are returned.
 * @param maxTimelineBytes Largest timeline; a larger one is left out.
 */
data class DevRecordingExportOptions(
    val lastSeconds: Int? = null,
    val maxVideoBytes: Long? = null,
    val maxTimelineBytes: Int? = null,
)

/**
 * Files of an exported screen recording. They stay valid until the next export.
 *
 * @param video `recording.mp4`, H.264 at 3 frames per second; `null` when it stayed above the size limit even at half
 * size, and then the other files are `null` too.
 * @param frames `frames.jpg`, a contact sheet with a timestamp on every frame; `null` when it could not be written.
 * @param timeline `timeline.md`, a table of frames and touches; `null` when it was left out.
 */
class DevRecordingExport(
    val video: File?,
    val frames: File?,
    val timeline: File?,
)
