package com.appswithlove.debug.ui.dev.log

import co.touchlab.kermit.LogWriter
import co.touchlab.kermit.Severity

/** No-op stub: production builds discard Kermit logs instead of forwarding them to a debug panel. */
@Suppress("UNUSED_PARAMETER")
class DevKermitLogWriter(
    logCollector: DevLogCollector = LogCollector.devLogCollector,
) : LogWriter() {
    override fun log(severity: Severity, message: String, tag: String, throwable: Throwable?) {}
}
