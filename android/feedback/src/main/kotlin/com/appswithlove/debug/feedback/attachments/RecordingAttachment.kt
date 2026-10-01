package com.appswithlove.debug.feedback.attachments

import android.util.Log
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevRecordingExport
import com.appswithlove.debug.api.extension.DevRecordingExportOptions
import com.appswithlove.debug.feedback.FeedbackPart
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException

private const val LOG_TAG = "Feedback"

/** Limits of the feedback service: the last minute of activity, `video` up to 25 MB, `timeline` up to 256 KiB. */
internal val FEEDBACK_RECORDING_OPTIONS = DevRecordingExportOptions(
    lastSeconds = 60,
    maxVideoBytes = 25L * 1024 * 1024,
    maxTimelineBytes = 256 * 1024,
)

/** Parts `video`, `frames` and `timeline`; empty with [isVideoTooLarge] when the video exceeded 25 MB. */
internal class RecordingAttachment(val parts: List<FeedbackPart>, val isVideoTooLarge: Boolean)

/** Whether the debug panel has a recording to offer. */
internal fun hasRecordingToAttach(source: () -> Boolean = AwlDebugExtensions::hasRecording): Boolean =
    runCatching { source() }.getOrDefault(false)

/** Asks the debug panel for its recording; `null` without the panel, without frames, or when it fails. */
internal suspend fun captureRecordingAttachment(
    source: suspend () -> DevRecordingExport? = { AwlDebugExtensions.exportRecording(FEEDBACK_RECORDING_OPTIONS) },
): RecordingAttachment? {
    val export = try {
        source()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.w(LOG_TAG, "Could not prepare the recording for the report", e)
        null
    } ?: return null
    val video = export.video ?: return RecordingAttachment(parts = emptyList(), isVideoTooLarge = true)
    return withContext(Dispatchers.IO) {
        try {
            RecordingAttachment(
                parts = listOfNotNull(
                    FeedbackPart("video", "recording.mp4", "video/mp4", video.readBytes()),
                    export.frames?.let { FeedbackPart("frames", "frames.jpg", "image/jpeg", it.readBytes()) },
                    export.timeline?.let { FeedbackPart("timeline", "timeline.md", "text/markdown; charset=utf-8", it.readBytes()) },
                ),
                isVideoTooLarge = false,
            )
        } catch (e: IOException) {
            Log.w(LOG_TAG, "Could not read the recording for the report", e)
            null
        }
    }
}
