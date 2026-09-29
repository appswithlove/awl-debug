package com.appswithlove.debug.feedback

import com.appswithlove.debug.api.AwlDistribution

/**
 * Connects the feedback flow to the feedback service.
 *
 * @param endpoint Base URL of the service; reports go to `{endpoint}/v1/feedback`.
 * @param appKey Key the service issued for this app (routing only, not a secret).
 * @param extraMetadata Called when a report starts; a `screen` entry becomes the report's current screen.
 * @param shakeToReport Shaking the device starts a report while the app is in the foreground.
 * @param distribution Sent as `distribution` when set. Leave `null` for services that do not accept the field yet.
 * @param reporter Sent as `reporter` when set. Leave `null` for services that do not accept the field yet.
 * @param attachLogsByDefault Initial state of "Attach logs": recent logs and requests of the debug panel go along as `logs.txt`.
 */
data class FeedbackConfig(
    val endpoint: String,
    val appKey: String,
    val appVersion: String,
    val buildNumber: String,
    val environment: String,
    val extraMetadata: () -> Map<String, String> = { emptyMap() },
    val shakeToReport: Boolean = true,
    val distribution: AwlDistribution? = null,
    val reporter: FeedbackReporter? = null,
    val attachLogsByDefault: Boolean = true,
)

/** Person who sends the report, shown to the team that handles it. */
data class FeedbackReporter(
    val name: String,
    val email: String? = null,
)
