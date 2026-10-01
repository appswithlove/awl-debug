package com.appswithlove.debug.api.bridge

import com.appswithlove.debug.api.DevTrigger
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Lets the feedback artifact read data of the debug panel without depending on it.
 * The debug artifact fills the slots, the no-op artifacts leave them `null`. Only platform types cross it.
 */
@AwlDebugInternalApi
object DevBridge {
    /**
     * Returns the logs and network section of the feedback attachment `logs.txt` as UTF-8, starting with its
     * `filters:` line and at most [LOGS_ATTACHMENT_BODY_MAX_BYTES] long, or `null` when there is nothing to attach.
     */
    @Volatile
    var feedbackAttachments: (suspend () -> ByteArray?)? = null

    /**
     * Set by the feedback artifact while a configured `FeedbackHost` is shown; the panel then offers
     * "Send feedback" and leaves the feedback triggers to it.
     */
    val feedbackLauncher: MutableStateFlow<FeedbackEntry?> = MutableStateFlow(null)

    /** `true` while the panel keeps frames of this or the previous app run. */
    @Volatile
    var hasRecording: (() -> Boolean)? = null

    /**
     * Prepares the screen recording for a report: this run's frames, or the previous run's when this one has none.
     * Returns `null` without frames. Takes a while, call it off the main thread.
     */
    @Volatile
    var lastRecording: (suspend () -> RecordingExport?)? = null

    /** Room left in the 1 MiB `logs.txt` for the header that the feedback artifact writes. */
    const val LOGS_ATTACHMENT_BODY_MAX_BYTES: Int = 1024 * 1024 - 4 * 1024
}

/**
 * A feedback flow the panel can start.
 *
 * @param triggers Gestures that start feedback; the panel ignores them for itself.
 * @param pendingCount Reports waiting in the offline queue.
 * @param start Starts a report; call it on the main thread.
 */
@AwlDebugInternalApi
class FeedbackEntry(
    val triggers: Set<DevTrigger>,
    val pendingCount: StateFlow<Int>,
    val start: () -> Unit,
)

/**
 * Files of a recording for the feedback parts `video`, `frames` and `timeline`. [video] is `null` when it stayed above
 * 25 MB even at half size; the other files are then `null` too.
 */
@AwlDebugInternalApi
class RecordingExport(
    val video: File?,
    val frames: File?,
    val timeline: File?,
)
