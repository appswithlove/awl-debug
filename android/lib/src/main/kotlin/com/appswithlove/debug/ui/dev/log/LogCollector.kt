package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.bridge.LogsAttachment

object LogCollector {
    val logHistory = LogHistory()
    val devLogCollector: DevLogCollector = DevLogWriter(logHistory)

    init {
        LogsAttachment.register()
    }
}
