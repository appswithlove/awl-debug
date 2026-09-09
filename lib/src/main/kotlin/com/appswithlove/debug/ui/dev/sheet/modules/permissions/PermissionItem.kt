package com.appswithlove.debug.ui.dev.sheet.modules.permissions

data class PermissionItem(
    val name: String,
    val isGranted: Boolean,
    val origin: PermissionOrigin,
    val description: String?,
)
