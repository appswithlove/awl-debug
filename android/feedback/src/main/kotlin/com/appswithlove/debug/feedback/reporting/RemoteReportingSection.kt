package com.appswithlove.debug.feedback.reporting

import com.appswithlove.debug.api.extension.DevExtensionAction
import com.appswithlove.debug.api.extension.DevExtensionItem
import com.appswithlove.debug.api.extension.DevExtensionSection
import com.appswithlove.debug.api.extension.DevTextStyle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.text.DateFormat
import java.util.Date

/** Panel section below App Info, directly above "Send feedback". */
internal const val REPORTING_SECTION_ORDER = 10

/** Panel section for [status]; it follows every status change within [scope]. */
internal fun remoteReportingSection(
    status: StateFlow<ReportingStatus>,
    scope: CoroutineScope,
    onFlushNow: () -> Unit,
    onSendingChanged: (Boolean) -> Unit,
): DevExtensionSection {
    fun items(current: ReportingStatus) = remoteReportingItems(current, onFlushNow, onSendingChanged)
    return DevExtensionSection(
        id = "remote-reporting",
        items = status.map(::items).stateIn(scope, SharingStarted.Eagerly, items(status.value)),
        order = REPORTING_SECTION_ORDER,
    )
}

/** Rows of the section; none until reporting was started. */
internal fun remoteReportingItems(
    status: ReportingStatus,
    onFlushNow: () -> Unit,
    onSendingChanged: (Boolean) -> Unit,
): List<DevExtensionItem> = buildList {
    if (!status.isConfigured) return@buildList
    val flushNow = DevExtensionAction("Flush now", enabled = status.isSendingEnabled, onClick = onFlushNow)
    add(
        DevExtensionItem.Title(
            text = "Remote reporting: ${if (status.isOn) "On" else "Off"}",
            action = flushNow.takeIf { !status.isStoreBuild && status.stoppedStatus == null },
        ),
    )
    problem(status)?.let { add(DevExtensionItem.Text(it, DevTextStyle.Error)) }
    if (status.isStoreBuild) return@buildList

    val summary = listOfNotNull("${status.pendingEntries} pending", status.lastSentMillis?.let { "Last sent ${time(it)}" })
    add(DevExtensionItem.Text(summary.joinToString(" · ")))
    status.sessionId?.let { add(DevExtensionItem.Text("Session ID: $it", DevTextStyle.Monospace, copyValue = it)) }
    add(DevExtensionItem.Switch("Send session data", checked = status.isSendingEnabled, onCheckedChange = onSendingChanged))
}

private fun problem(status: ReportingStatus): String? = when {
    status.isStoreBuild -> "Reporting is off in store builds."
    status.stoppedStatus == 403 -> "Reporting is disabled for this app in the dashboard."
    status.stoppedStatus != null -> "Invalid or disabled app key."
    status.rejectedStatus != null -> "The dashboard rejected a batch (${status.rejectedStatus})."
    status.isWaitingForUnmeteredNetwork -> "Waiting for an unmetered network."
    status.isRetrying -> "Sending failed, retrying later."
    else -> null
}

private fun time(millis: Long): String = DateFormat.getTimeInstance(DateFormat.MEDIUM).format(Date(millis))
