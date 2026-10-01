package com.appswithlove.debug.feedback

import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.atomic.AtomicReference

/** Starts reports from code, e.g. from an app's own menu. */
object AwlFeedback {
    /**
     * Starts a report in the configured [FeedbackHost] that was shown last. Does nothing while a report is open
     * or when no configured [FeedbackHost] is shown. Safe to call from any thread.
     */
    fun start() {
        val mainLooper = Looper.getMainLooper()
        if (Looper.myLooper() != mainLooper) {
            Handler(mainLooper).post(::start)
            return
        }
        val host = ActiveFeedbackHost.current
        if (host == null) {
            Log.w("Feedback", "AwlFeedback.start() ignored: no FeedbackHost with a config is shown")
            return
        }
        host.start()
    }
}

/** Starts a report in a [FeedbackHost]. */
internal fun interface ReportStarter {
    fun start()
}

/** The configured [FeedbackHost] resumed last; reports started from code or from the debug panel open there. */
internal object ActiveFeedbackHost {
    private val host = AtomicReference<ReportStarter?>(null)

    val current: ReportStarter? get() = host.get()

    fun set(starter: ReportStarter) {
        host.set(starter)
    }

    fun clear(starter: ReportStarter) {
        host.compareAndSet(starter, null)
    }
}
