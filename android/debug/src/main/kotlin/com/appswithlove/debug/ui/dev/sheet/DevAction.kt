package com.appswithlove.debug.ui.dev.sheet

internal sealed class DevAction {
    data object ActivateDevTool : DevAction()
    data class ShowDevSheet(val show: Boolean? = null) : DevAction()
}
