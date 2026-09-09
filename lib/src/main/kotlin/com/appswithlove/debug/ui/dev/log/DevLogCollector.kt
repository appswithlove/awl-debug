package com.appswithlove.debug.ui.dev.log

interface DevLogCollector {
    fun setTrackLogs(track: Boolean)
    fun log(log: Log)
    fun setMaxSize(size: Int)
}
