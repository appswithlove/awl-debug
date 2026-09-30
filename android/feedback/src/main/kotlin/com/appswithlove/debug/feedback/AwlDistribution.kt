package com.appswithlove.debug.feedback

/**
 * How a build reaches its users. Sent with feedback and session data so the service can tell test builds apart.
 *
 * @property wireValue Value used in requests to AWL services.
 */
enum class AwlDistribution(val wireValue: String) {
    /** Local or CI debug build. */
    Debug("debug"),

    /** Internal test distribution, for example staging builds for testers. */
    Internal("internal"),

    /** Store build. The SDK is never part of such builds; the value exists so services can reject it. */
    Store("store"),
}
