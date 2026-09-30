package com.appswithlove.debug.feedback

import com.appswithlove.debug.api.AwlDistribution
import com.appswithlove.debug.api.DevTrigger

/**
 * Connects the feedback flow to the feedback service.
 *
 * @param endpoint Base URL of the service; reports go to `{endpoint}/v1/feedback`.
 * @param appKey Key the service issued for this app (routing only, not a secret).
 * @param extraMetadata Called when a report starts; a `screen` entry becomes the report's current screen.
 * @param triggers Gestures that start a report while the app is in the foreground. [DevTrigger.Screenshot] needs
 * Android 14 (API 34). A trigger listed here and in the `DevSheet` starts feedback only.
 * @param distribution Sent as `distribution` when set. Leave `null` for services that do not accept the field yet.
 * @param reporter Prefills who sends the report. Without it the first report asks for a name (email optional); testers can change it and the entry is kept on the device.
 * @param attachLogsByDefault Initial state of "Attach logs": recent logs and requests of the debug panel go along as `logs.txt`.
 */
data class FeedbackConfig(
    val endpoint: String,
    val appKey: String,
    val appVersion: String,
    val buildNumber: String,
    val environment: String,
    val extraMetadata: () -> Map<String, String> = { emptyMap() },
    val triggers: Set<DevTrigger> = DEFAULT_FEEDBACK_TRIGGERS,
    val distribution: AwlDistribution? = null,
    val reporter: FeedbackReporter? = null,
    val attachLogsByDefault: Boolean = true,
) {
    @Deprecated(
        "Use triggers.",
        ReplaceWith(
            "FeedbackConfig(endpoint, appKey, appVersion, buildNumber, environment, extraMetadata, " +
                "if (shakeToReport) setOf(DevTrigger.Shake, DevTrigger.Screenshot) else setOf(DevTrigger.Screenshot), " +
                "distribution, reporter, attachLogsByDefault)",
        ),
    )
    constructor(
        endpoint: String,
        appKey: String,
        appVersion: String,
        buildNumber: String,
        environment: String,
        extraMetadata: () -> Map<String, String> = { emptyMap() },
        shakeToReport: Boolean,
        distribution: AwlDistribution? = null,
        reporter: FeedbackReporter? = null,
        attachLogsByDefault: Boolean = true,
    ) : this(
        endpoint = endpoint,
        appKey = appKey,
        appVersion = appVersion,
        buildNumber = buildNumber,
        environment = environment,
        extraMetadata = extraMetadata,
        triggers = if (shakeToReport) DEFAULT_FEEDBACK_TRIGGERS else DEFAULT_FEEDBACK_TRIGGERS - DevTrigger.Shake,
        distribution = distribution,
        reporter = reporter,
        attachLogsByDefault = attachLogsByDefault,
    )

    @Deprecated("Use triggers.", ReplaceWith("DevTrigger.Shake in triggers"))
    val shakeToReport: Boolean get() = DevTrigger.Shake in triggers
}

private val DEFAULT_FEEDBACK_TRIGGERS = setOf(DevTrigger.Shake, DevTrigger.Screenshot)

/** Person who sends the report, shown to the team that handles it. */
data class FeedbackReporter(
    val name: String,
    val email: String? = null,
)
