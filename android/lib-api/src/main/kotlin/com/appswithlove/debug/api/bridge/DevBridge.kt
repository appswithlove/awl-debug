package com.appswithlove.debug.api.bridge

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

    /** Room left in the 1 MiB `logs.txt` for the header that the feedback artifact writes. */
    const val LOGS_ATTACHMENT_BODY_MAX_BYTES: Int = 1024 * 1024 - 4 * 1024
}
