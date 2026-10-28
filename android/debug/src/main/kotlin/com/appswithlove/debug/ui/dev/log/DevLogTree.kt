package com.appswithlove.debug.ui.dev.log

import android.util.Log
import timber.log.Timber

@Suppress("Unused")
class DevLogTree(
    private val logCollector: DevLogCollector = LogCollector.devLogCollector,
) : Timber.Tree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        val severity = when (priority) {
            Log.VERBOSE, Log.DEBUG -> DevLogSeverity.DEBUG
            Log.INFO -> DevLogSeverity.INFO
            Log.WARN -> DevLogSeverity.WARN
            Log.ERROR, Log.ASSERT -> DevLogSeverity.ERROR
            else -> DevLogSeverity.INFO
        }
        // Timber appends the stack trace to the message; keep it only once, as the throwable.
        val text = t?.let { message.removeSuffix(it.stackTraceToString()).removeSuffix("\n") } ?: message
        logCollector.log(Log(severity, text, tag, t))
    }
}
