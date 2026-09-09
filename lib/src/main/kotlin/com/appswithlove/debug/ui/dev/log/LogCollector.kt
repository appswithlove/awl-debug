package com.appswithlove.debug.ui.dev.log

object LogCollector {
    val logHistory = LogHistory()
    val devLogCollector = DevLogWriter(logHistory)
}
