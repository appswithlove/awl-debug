package com.appswithlove.debug.ui.dev.log

object LogCollector {
    val logHistory: LogHistory = LogHistory()
    val devLogCollector: DevLogCollector = NoOpDevLogCollector
}

private object NoOpDevLogCollector : DevLogCollector {
    override fun setTrackLogs(track: Boolean) {}
    override fun log(log: Log) {}
    override fun setMaxSize(size: Int) {}
}
