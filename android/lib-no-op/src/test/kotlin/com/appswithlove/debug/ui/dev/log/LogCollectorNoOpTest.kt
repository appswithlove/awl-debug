package com.appswithlove.debug.ui.dev.log

import io.kotest.matchers.shouldNotBe
import org.junit.Test

class LogCollectorNoOpTest {

    @Test
    fun devLogCollector_operations_doNotThrow() {
        val collector = LogCollector.devLogCollector
        collector.log(Log(DevLogSeverity.INFO, "hello"))
        collector.log(Log(DevLogSeverity.ERROR, "boom"))
        collector.setMaxSize(100)
        collector.setTrackLogs(true)
        collector.setTrackLogs(false)
    }

    @Test
    fun logHistory_isAvailable() {
        LogCollector.logHistory shouldNotBe null
    }
}
