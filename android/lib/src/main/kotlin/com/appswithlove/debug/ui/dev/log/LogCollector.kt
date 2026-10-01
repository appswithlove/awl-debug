package com.appswithlove.debug.ui.dev.log

import com.appswithlove.debug.extension.DebugExtensionProvider

object LogCollector {
    val logHistory = LogHistory()
    val devLogCollector: DevLogCollector = DevLogWriter(logHistory)

    init {
        DebugExtensionProvider.install()
    }
}
