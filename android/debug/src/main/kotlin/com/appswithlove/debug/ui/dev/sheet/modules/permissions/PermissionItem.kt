package com.appswithlove.debug.ui.dev.sheet.modules.permissions

internal data class PermissionItem(
    val name: String,
    val isGranted: Boolean,
    val origin: PermissionOrigin,
    val description: String?,
)
