package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.R
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevOutlinedTextField
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.component.SelectionDialog
import com.appswithlove.debug.ui.component.ShareLogsButton
import com.appswithlove.debug.ui.dev.log.DevLogSeverity
import com.appswithlove.debug.ui.dev.log.LogHistory
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun LogsModule(
    modifier: Modifier = Modifier,
    logHistory: LogHistory,
    onEntryLongPress: (String) -> Unit,
    onMaxLogsChanged: (Int) -> Unit,
) {
    val selectedSeverityTags = logHistory.selectedSeverityTags.collectAsState()
    val logs = logHistory.filteredLogEntries.collectAsState(initial = emptyList()).value.filter {
        if (selectedSeverityTags.value.isEmpty()) {
            true
        } else {
            it.severity in selectedSeverityTags.value
        }
    }
    val trackLogs = logHistory.trackLogs.collectAsState()
    val maxLogsSize = logHistory.maxSize.collectAsState()
    val logsSizeOptions = listOf(10, 50, 250, 500, 750, 1000)
    val query = logHistory.query.collectAsState()
    val logsSettingTitle = "Number of logs per session"
    val showLogsPerSessionDialog = remember { mutableStateOf(false) }
    val logEntryExpanded = remember { mutableStateOf(false) }

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {

        AnimatedVisibility(visible = trackLogs.value) {
            Column {
                DevOutlinedTextField(
                    modifier = Modifier.fillMaxWidth(),
                    value = query.value,
                    placeholder = "Search logs",
                    onValueChange = { logHistory.search(it) },
                    onClear = { logHistory.search("") }
                )

                FlowRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    DevLogSeverity.entries.forEach { severity ->
                        FilterChip(
                            modifier = Modifier.height(28.dp),
                            onClick = {
                                logHistory.filterBySeverity(severity)
                            },
                            label = {
                                Text(
                                    text = severity.name,
                                    style = MaterialTheme.typography.labelMedium,
                                )
                            },
                            selected = severity in selectedSeverityTags.value,
                            colors = FilterChipDefaults.filterChipColors().copy(
                                selectedContainerColor = MaterialTheme.colorScheme.onSurface,
                                selectedLabelColor = AppTheme.colors.background,
                            )
                        )
                    }
                }

            }
        }

        if (trackLogs.value) {
            LazyColumn(
                modifier = Modifier
                    .weight(1f, fill = false)
                    .fillMaxWidth()
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.onSurface,
                        shape = RoundedCornerShape(4.dp),
                    ),
                reverseLayout = true,
                contentPadding = PaddingValues(4.dp),
                verticalArrangement = Arrangement.Center,
            ) {
                if (logs.isEmpty()) {
                    item {
                        Text(
                            text = "Empty",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                } else {
                    itemsIndexed(logs.reversed()) { index, entry ->
                        val text = entry.message

                        if (entry.severity in selectedSeverityTags.value || selectedSeverityTags.value.isEmpty()) {
                            Column(
                                modifier = Modifier
                                    .pointerInput(Unit) {
                                        detectTapGestures(
                                            onLongPress = { onEntryLongPress(text) },
                                            onTap = {
                                                logEntryExpanded.value = !logEntryExpanded.value
                                            },
                                        )
                                    },
                            ) {
                                Text(
                                    text = entry.formattedTime,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                )
                                Text(
                                    text = buildAnnotatedString {
                                        if (entry.severity != null) {
                                            val tagColor = when (entry.severity) {
                                                DevLogSeverity.DEBUG -> {
                                                    MaterialTheme.colorScheme.onSurface.copy(
                                                        alpha = 0.5f,
                                                    )
                                                }

                                                DevLogSeverity.INFO -> AppTheme.colors.info
                                                DevLogSeverity.WARN -> AppTheme.colors.warning
                                                DevLogSeverity.ERROR -> AppTheme.colors.error
                                            }
                                            withStyle(
                                                SpanStyle(
                                                    color = tagColor,
                                                    fontWeight = FontWeight.Bold
                                                )
                                            ) {
                                                append(entry.severity.name)
                                            }
                                        }
                                        withStyle(
                                            SpanStyle(color = MaterialTheme.colorScheme.onSurface),
                                        ) {
                                            append(" | $text")
                                        }
                                    },
                                    style = MaterialTheme.typography.bodySmall,
                                    overflow = if (logEntryExpanded.value) TextOverflow.Visible else TextOverflow.Ellipsis,
                                    maxLines = if (logEntryExpanded.value) Int.MAX_VALUE else 3,
                                )
                                if (index != 0 && logs.size > 1) {
                                    HorizontalDivider()
                                }
                            }
                        }
                    }
                }
            }
        }

        AnimatedVisibility(visible = trackLogs.value) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ShareLogsButton(
                    modifier = Modifier.weight(1f),
                    logHistory = logHistory,
                )

                DevOutlinedButton(
                    modifier = Modifier.weight(1f),
                    text = "Clear Logs",
                    leadingIcon = {
                        Icon(
                            modifier = Modifier.size(18.dp),
                            imageVector = TablerIcons.TrashX,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    },
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    onClick = { logHistory.clear() },
                )
            }
        }

        AnimatedVisibility(visible = trackLogs.value) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp)
                    .clickable {
                        showLogsPerSessionDialog.value = true
                    },
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = logsSettingTitle,
                    modifier = Modifier
                        .weight(1f)
                        .padding(end = 12.dp),
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = maxLogsSize.value.toString(),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
                Icon(
                    painter = painterResource(R.drawable.ic_chevron_right),
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                )
            }
        }
    }

    SelectionDialog(
        show = showLogsPerSessionDialog,
        title = logsSettingTitle,
        values = logsSizeOptions,
        selectedOption = maxLogsSize.value,
        onOptionSelected = {
            onMaxLogsChanged(it)
            showLogsPerSessionDialog.value = false
        },
    )
}

@Preview(showBackground = true)
@Composable
private fun LogsModulePreview() {
    DevTheme {
        LogsModule(
            modifier = Modifier.padding(8.dp),
            logHistory = LogHistory.Preview,
            onEntryLongPress = {},
            onMaxLogsChanged = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun LogsModuleEmptyPreview() {
    DevTheme {
        LogsModule(
            modifier = Modifier.padding(8.dp),
            logHistory = LogHistory.PreviewEmpty,
            onEntryLongPress = {},
            onMaxLogsChanged = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun LogsModuleTrackLogsDisabledPreview() {
    DevTheme {
        LogsModule(
            modifier = Modifier.padding(8.dp),
            logHistory = LogHistory.PreviewTrackLogsDisabled,
            onEntryLongPress = {},
            onMaxLogsChanged = {},
        )
    }
}
