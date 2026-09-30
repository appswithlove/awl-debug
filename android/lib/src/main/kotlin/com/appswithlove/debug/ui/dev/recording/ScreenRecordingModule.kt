package com.appswithlove.debug.ui.dev.recording

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.appswithlove.debug.R
import com.appswithlove.debug.api.DevScreenRecordingConfig
import com.appswithlove.debug.ui.component.DevSwitchRow
import com.appswithlove.debug.ui.component.SelectionDialog
import com.appswithlove.debug.ui.component.findActivity
import java.text.DateFormat
import java.util.Date

/** Starts the recorder for the hosting activity and pauses it while the panel is open. */
@Composable
internal fun ScreenRecordingEffect(config: DevScreenRecordingConfig, isPanelOpen: Boolean) {
    val activity = LocalContext.current.findActivity() ?: return
    LaunchedEffect(activity) { ScreenRecorder.install(activity, config) }
    LaunchedEffect(isPanelOpen) { ScreenRecorder.setPanelOpen(isPanelOpen) }
}

@Composable
internal fun ScreenRecordingModule(modifier: Modifier = Modifier) {
    val isOn by ScreenRecorder.isOn.collectAsStateWithLifecycle()
    val maxDuration by ScreenRecorder.maxDurationSeconds.collectAsStateWithLifecycle()
    val lastRecording by ScreenRecorder.lastRecording.collectAsStateWithLifecycle()
    val showDurationDialog = remember { mutableStateOf(false) }
    val secondaryColor = MaterialTheme.colorScheme.onSurfaceVariant

    Column(modifier = modifier.padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DevSwitchRow(text = "Screen recording", checked = isOn, onCheckedChange = ScreenRecorder::setOn)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showDurationDialog.value = true }
                .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Max duration", modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurface)
            Text(text = durationLabel(maxDuration), color = secondaryColor)
            Icon(
                painter = painterResource(R.drawable.ic_chevron_right),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
        Text(
            text = lastRecording?.let { "Last recording available (${recordingDate(it.endedAtMillis)})" }
                ?: "No recording yet",
            color = secondaryColor,
        )
        Text(
            text = "Recordings can contain personal data. Secure text fields are masked.",
            style = MaterialTheme.typography.bodySmall,
            color = secondaryColor,
        )
    }

    SelectionDialog(
        show = showDurationDialog,
        title = "Max duration",
        values = ScreenRecorder.durationOptionsSeconds,
        selectedOption = maxDuration,
        label = ::durationLabel,
        onOptionSelected = {
            ScreenRecorder.setMaxDurationSeconds(it)
            showDurationDialog.value = false
        },
    )
}

internal fun durationLabel(seconds: Int): String =
    if (seconds < 60) "$seconds sec" else if (seconds % 60 == 0) "${seconds / 60} min" else "$seconds sec"

private fun recordingDate(millis: Long): String =
    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(millis))
