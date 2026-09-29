package com.appswithlove.debug.api

/** Gestures that open the debug panel. Each works only while the tool is activated or `isAlwaysActive` is set. */
enum class DevTrigger {
    /** Three fingers at once; two on an emulator. */
    ThreeFingerTap,

    /** Three taps with one finger within 600 ms, alongside the app's own gestures. */
    TripleTap,

    /** A system screenshot. Android 14 (API 34) and later; ignored below. */
    Screenshot,

    /** Shaking the device. */
    Shake,
}
