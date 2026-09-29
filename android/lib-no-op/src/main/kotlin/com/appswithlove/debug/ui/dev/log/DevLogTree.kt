package com.appswithlove.debug.ui.dev.log

import timber.log.Timber

/** No-op stub: production builds discard Timber logs instead of forwarding them to a debug panel. */
@Suppress("UNUSED_PARAMETER")
class DevLogTree(
    logCollector: DevLogCollector = LogCollector.devLogCollector,
) : Timber.Tree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {}
}
