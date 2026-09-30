package com.appswithlove.debug.feedback

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.DevBridge

/** Starts reports from code, e.g. from an app's own menu. */
object AwlFeedback {
    /**
     * Starts a report in the configured [FeedbackHost] that was shown last. Does nothing while a report is open
     * or when no configured [FeedbackHost] is shown. Safe to call from any thread.
     */
    @OptIn(AwlDebugInternalApi::class)
    fun start() {
        val mainLooper = Looper.getMainLooper()
        if (Looper.myLooper() != mainLooper) {
            Handler(mainLooper).post(::start)
            return
        }
        val entry = DevBridge.feedbackLauncher.value
        if (entry == null) {
            Log.w("Feedback", "AwlFeedback.start() ignored: no FeedbackHost with a config is shown")
            return
        }
        entry.start()
    }
}
