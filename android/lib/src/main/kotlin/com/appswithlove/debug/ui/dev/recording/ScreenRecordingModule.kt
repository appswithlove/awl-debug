package com.appswithlove.debug.ui.dev.recording

import android.content.Context
import android.util.Log
import android.widget.Toast
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
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.appswithlove.debug.R
import com.appswithlove.debug.api.DevScreenRecordingConfig
import com.appswithlove.debug.ui.component.DevSwitch
import com.appswithlove.debug.ui.component.SelectionDialog
import com.appswithlove.debug.ui.component.findActivity
import com.appswithlove.debug.ui.component.shareFile
import java.text.DateFormat
import java.util.Date
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
    val isExporting = remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val secondaryColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)

    Column(modifier = modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(text = "Screen recording", modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurface)
            DevSwitch(checked = isOn, onCheckedChange = ScreenRecorder::setOn)
        }
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
        listOf(false to "Export current recording", true to "Export last recording").forEach { (last, label) ->
            Text(
                text = if (isExporting.value) "$label…" else label,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = !isExporting.value) { exportRecording(context, scope, last, isExporting) }
                    .padding(vertical = 6.dp),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = if (isExporting.value) 0.38f else 1f),
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

/** Shares the recording as a ZIP with `recording.mp4`, `frames.jpg` and `timeline.md`. */
private fun exportRecording(
    context: Context,
    scope: CoroutineScope,
    last: Boolean,
    isExporting: MutableState<Boolean>,
) {
    val recordingDir = ScreenRecorder.recordingDir(last)
    val exportDir = ScreenRecorder.exportDir("recording-export")
    isExporting.value = true
    scope.launch {
        try {
            val result = if (recordingDir == null || exportDir == null) {
                Result.success(null)
            } else {
                withContext(Dispatchers.IO) { runCatching { RecordingExporter.exportZip(recordingDir, exportDir) } }
            }
            val zip = result.getOrNull()
            when {
                zip != null -> shareFile(context, zip, "application/zip", "Share recording")
                result.isFailure -> {
                    Log.w("AwlDebugRecording", "Could not export the recording", result.exceptionOrNull())
                    Toast.makeText(context, "Could not export the recording", Toast.LENGTH_SHORT).show()
                }
                else -> Toast.makeText(context, "No recording yet", Toast.LENGTH_SHORT).show()
            }
        } finally {
            isExporting.value = false
        }
    }
}

internal fun durationLabel(seconds: Int): String =
    if (seconds < 60) "$seconds sec" else if (seconds % 60 == 0) "${seconds / 60} min" else "$seconds sec"

private fun recordingDate(millis: Long): String =
    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(millis))
