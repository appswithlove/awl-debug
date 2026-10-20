package com.appswithlove.debug.api

/**
 * Defaults of the Screen Recording module. Testers can change both on the device.
 *
 * @param isOnByDefault Records from the first start until a tester turns recording off.
 * @param maxDurationSeconds Length of the ring buffer in active seconds (3 frames per second).
 */
data class DevScreenRecordingConfig(
    val isOnByDefault: Boolean = false,
    val maxDurationSeconds: Int = 300,
)
