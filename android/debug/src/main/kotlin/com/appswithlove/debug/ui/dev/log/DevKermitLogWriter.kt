package com.appswithlove.debug.ui.dev.log

import co.touchlab.kermit.LogWriter
import co.touchlab.kermit.Severity

/**
 * Kermit [LogWriter] that forwards logs to the panel's Logs module, keeping the Kermit tag and throwable.
 * Kermit is a `compileOnly` dependency: the app brings its own Kermit version.
 */
@Suppress("Unused")
class DevKermitLogWriter(
    private val logCollector: DevLogCollector = LogCollector.devLogCollector,
) : LogWriter() {
    override fun log(severity: Severity, message: String, tag: String, throwable: Throwable?) {
        val devSeverity = when (severity) {
            Severity.Verbose, Severity.Debug -> DevLogSeverity.DEBUG
            Severity.Info -> DevLogSeverity.INFO
            Severity.Warn -> DevLogSeverity.WARN
            Severity.Error, Severity.Assert -> DevLogSeverity.ERROR
        }
        logCollector.log(Log(devSeverity, message, tag.ifBlank { null }, throwable))
    }
}
