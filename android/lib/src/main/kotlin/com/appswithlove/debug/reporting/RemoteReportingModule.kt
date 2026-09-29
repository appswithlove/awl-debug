package com.appswithlove.debug.reporting

import android.content.ClipData
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.appswithlove.debug.ui.component.DevSwitch
import kotlinx.coroutines.launch
import java.text.DateFormat
import java.util.Date

/** Panel row below App Info; shown only when the app started remote reporting. */
@Composable
internal fun RemoteReportingModule() {
    val status by RemoteReporting.status.collectAsStateWithLifecycle()
    if (!status.isConfigured) return
    RemoteReportingRow(
        status = status,
        onFlushNow = RemoteReporting::flush,
        onSendingChanged = RemoteReporting::setSendingEnabled,
    )
}

@Composable
internal fun RemoteReportingRow(
    status: ReportingStatus,
    onFlushNow: () -> Unit,
    onSendingChanged: (Boolean) -> Unit,
) {
    val secondary = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    val clipboard = LocalClipboard.current
    val scope = rememberCoroutineScope()

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                modifier = Modifier.weight(1f),
                text = "Remote reporting: ${if (status.isOn) "On" else "Off"}",
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight(800)),
                color = MaterialTheme.colorScheme.onSurface,
            )
            if (!status.isStoreBuild && status.stoppedStatus == null) {
                TextButton(onClick = onFlushNow, enabled = status.isSendingEnabled) { Text("Flush now") }
            }
        }
        problem(status)?.let { Text(text = it, color = MaterialTheme.colorScheme.error) }
        if (status.isStoreBuild) return@Column

        Text(
            text = listOfNotNull(
                "${status.pendingEntries} pending",
                status.lastSentMillis?.let { "Last sent ${time(it)}" },
            ).joinToString(" · "),
            color = secondary,
        )
        status.sessionId?.let { sessionId ->
            Text(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        scope.launch { clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("Session ID", sessionId))) }
                    }
                    .padding(vertical = 4.dp),
                text = "Session ID: $sessionId",
                style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                color = secondary,
            )
        }
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                modifier = Modifier.weight(1f),
                text = "Send session data",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            DevSwitch(checked = status.isSendingEnabled, onCheckedChange = onSendingChanged)
        }
    }
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
