package com.appswithlove.debug.api.reporting

import com.appswithlove.debug.api.AwlDistribution

/**
 * Sends sessions, network requests and performance samples of test builds to the feedback service.
 * Pass it to `AwlDebug.startRemoteReporting` in `Application.onCreate`.
 *
 * Nothing is recorded or sent when [distribution] is [AwlDistribution.Store].
 *
 * @param endpoint Base URL of the feedback service, for example `https://feedback.example.com`.
 * @param appKey App key from the feedback service (sent as `X-App-Key`).
 * @param environment Free-form backend name the build talks to, for example `staging` or `prod`.
 * @param distribution How the build reaches its users.
 * @param captureBodies Send captured request and response bodies. Off by default.
 * @param maxBodyBytes Bodies are cut off after this many bytes. At most 65536.
 * @param onlyOnUnmeteredNetwork Only send over unmetered networks, for example Wi-Fi.
 */
data class RemoteReportingConfig(
    val endpoint: String,
    val appKey: String,
    val environment: String,
    val distribution: AwlDistribution,
    val captureBodies: Boolean = false,
    val maxBodyBytes: Int = MAX_BODY_BYTES,
    val onlyOnUnmeteredNetwork: Boolean = false,
) {
    override fun toString(): String =
        "RemoteReportingConfig(endpoint=$endpoint, appKey=[REDACTED], environment=$environment, " +
            "distribution=$distribution, captureBodies=$captureBodies, maxBodyBytes=$maxBodyBytes, " +
            "onlyOnUnmeteredNetwork=$onlyOnUnmeteredNetwork)"

    companion object {
        /** Upper limit for [maxBodyBytes] accepted by the service. */
        const val MAX_BODY_BYTES: Int = 64 * 1024
    }
}
