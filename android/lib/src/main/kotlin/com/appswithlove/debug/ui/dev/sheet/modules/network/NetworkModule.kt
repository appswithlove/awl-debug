package com.appswithlove.debug.ui.dev.sheet.modules.network

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.R
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevOutlinedTextField
import com.appswithlove.debug.ui.component.SelectionDialog
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.NetworkSort
import com.appswithlove.debug.ui.dev.network.NetworkUiState
import com.appswithlove.debug.ui.dev.network.StatusClass
import com.appswithlove.debug.ui.dev.network.statusText
import com.appswithlove.debug.ui.theme.AppTheme
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val LIMIT_OPTIONS = listOf(10, 50, 250, 500, 750, 1000)
private const val LIMIT_TITLE = "Number of logs per session"

@Composable
internal fun NetworkModule(
    state: NetworkUiState,
    onSearch: (String) -> Unit,
    onEntryClick: (NetworkEntry) -> Unit,
    onShowFilters: () -> Unit,
    onSortChanged: (NetworkSort) -> Unit,
    onClear: () -> Unit,
    onExport: () -> Unit,
    onMaxSizeChanged: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val showLimitDialog = remember { mutableStateOf(false) }
    var showClearDialog by remember { mutableStateOf(false) }

    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DevOutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = state.filter.query,
            placeholder = "Search requests",
            onValueChange = onSearch,
            onClear = { onSearch("") },
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                modifier = Modifier.weight(1f),
                text = "Number of requests: ${state.entries.size} / ${state.maxSize}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            TextButton(
                onClick = {
                    onSortChanged(
                        if (state.sort == NetworkSort.NewestFirst) NetworkSort.OldestFirst else NetworkSort.NewestFirst
                    )
                },
            ) {
                Icon(
                    modifier = Modifier.size(16.dp),
                    imageVector = TablerIcons.ArrowsSort,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    modifier = Modifier.padding(start = 4.dp),
                    text = state.sort.label,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }

        LazyColumn(
            modifier = Modifier
                .weight(1f, fill = false)
                .fillMaxWidth()
                .border(1.dp, MaterialTheme.colorScheme.onSurface, RoundedCornerShape(4.dp)),
            contentPadding = PaddingValues(4.dp),
        ) {
            if (state.entries.isEmpty()) {
                item {
                    Text(
                        modifier = Modifier.padding(8.dp),
                        text = "No requests yet",
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
            items(state.entries, key = { it.id }) { entry ->
                NetworkRow(entry = entry, onClick = { onEntryClick(entry) })
                HorizontalDivider()
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DevOutlinedButton(
                modifier = Modifier.weight(1f),
                text = "Filters",
                leadingIcon = { ButtonIcon(TablerIcons.Filter) },
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = onShowFilters,
            )
            DevOutlinedButton(
                modifier = Modifier.weight(1f),
                text = "Clear",
                leadingIcon = { ButtonIcon(TablerIcons.TrashX) },
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = { showClearDialog = true },
            )
        }
        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            text = "Export network logs",
            leadingIcon = { ButtonIcon(TablerIcons.Share) },
            contentColor = MaterialTheme.colorScheme.onSurface,
            onClick = onExport,
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showLimitDialog.value = true }
                .padding(top = 6.dp, bottom = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 12.dp),
                text = LIMIT_TITLE,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = state.maxSize.toString(),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
            Icon(
                painter = painterResource(R.drawable.ic_chevron_right),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }

    SelectionDialog(
        show = showLimitDialog,
        title = LIMIT_TITLE,
        values = LIMIT_OPTIONS,
        selectedOption = state.maxSize,
        onOptionSelected = {
            onMaxSizeChanged(it)
            showLimitDialog.value = false
        },
    )

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            title = { Text("Delete network logs?") },
            text = { Text("All captured requests will be removed.") },
            confirmButton = {
                TextButton(onClick = {
                    onClear()
                    showClearDialog = false
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun NetworkRow(entry: NetworkEntry, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(entry.startedAtMillis)),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                text = entry.method,
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = entry.statusText,
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                color = statusColor(entry),
            )
            Text(
                text = "${entry.durationMs} ms",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            )
            if (entry.isSlow) {
                Text(
                    text = "slow",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = AppTheme.colors.warning,
                )
            }
        }
        Text(
            text = entry.host + entry.path,
            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
internal fun statusColor(entry: NetworkEntry): Color = when (StatusClass.of(entry)) {
    StatusClass.Success -> AppTheme.colors.positive
    StatusClass.Redirection -> AppTheme.colors.redirect
    StatusClass.ClientError -> AppTheme.colors.warning
    StatusClass.ServerError -> AppTheme.colors.error
    StatusClass.Failed -> AppTheme.colors.info
    StatusClass.Informational -> MaterialTheme.colorScheme.onSurface
}

@Composable
internal fun ButtonIcon(imageVector: ImageVector) {
    Icon(
        modifier = Modifier.size(18.dp),
        imageVector = imageVector,
        contentDescription = null,
        tint = MaterialTheme.colorScheme.onSurface,
    )
}
