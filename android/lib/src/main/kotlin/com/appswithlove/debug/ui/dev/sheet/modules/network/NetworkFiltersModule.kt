package com.appswithlove.debug.ui.dev.sheet.modules.network

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevSectionTitle
import com.appswithlove.debug.ui.dev.network.NetworkUiState
import com.appswithlove.debug.ui.dev.network.StatusClass
import com.appswithlove.debug.ui.dev.network.toggle

@Composable
internal fun NetworkFiltersModule(
    state: NetworkUiState,
    onExcludedMethodsChanged: (Set<String>) -> Unit,
    onExcludedStatusClassesChanged: (Set<StatusClass>) -> Unit,
    onExcludedHostsChanged: (Set<String>) -> Unit,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.verticalScroll(rememberScrollState())) {
        FilterGroup(
            title = "Request Methods",
            description = "GET reads, POST creates, PUT and PATCH update, DELETE removes data.",
            values = state.methods,
            label = { it },
            excluded = state.filter.excludedMethods,
            onExcludedChanged = onExcludedMethodsChanged,
        )
        HorizontalDivider()
        FilterGroup(
            title = "Response Codes",
            description = "1xx informational, 2xx success, 3xx redirect, 4xx client error, " +
                "5xx server error. Failed: no response, for example offline or timeout.",
            values = StatusClass.entries,
            label = { it.label },
            excluded = state.filter.excludedStatusClasses,
            onExcludedChanged = onExcludedStatusClassesChanged,
        )
        HorizontalDivider()
        FilterGroup(
            title = "Hosts",
            description = null,
            values = state.hosts,
            label = { it },
            excluded = state.filter.excludedHosts,
            onExcludedChanged = onExcludedHostsChanged,
        )
        DevOutlinedButton(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            text = "Done",
            contentColor = MaterialTheme.colorScheme.onSurface,
            onClick = onDone,
        )
    }
}

@Composable
private fun <T> FilterGroup(
    title: String,
    description: String?,
    values: List<T>,
    label: (T) -> String,
    excluded: Set<T>,
    onExcludedChanged: (Set<T>) -> Unit,
) {
    Column(modifier = Modifier.padding(vertical = 8.dp)) {
        // The buttons move below the title when both do not fit, e.g. with a large font size.
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            itemVerticalAlignment = Alignment.CenterVertically,
        ) {
            DevSectionTitle(text = title)
            Row {
                TextButton(onClick = { onExcludedChanged(emptySet()) }) { Text("Select all") }
                TextButton(onClick = { onExcludedChanged(values.toSet()) }) { Text("Deselect all") }
            }
        }
        description?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
        if (values.isEmpty()) {
            Text(
                modifier = Modifier.padding(vertical = 8.dp),
                text = "No requests yet",
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
        values.forEach { value ->
            // One toggle per option, so TalkBack reads the label with the checkbox state.
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .toggleable(
                        value = value !in excluded,
                        role = Role.Checkbox,
                        onValueChange = { onExcludedChanged(excluded.toggle(value)) },
                    ),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Checkbox(checked = value !in excluded, onCheckedChange = null)
                Text(text = label(value), color = MaterialTheme.colorScheme.onSurface)
            }
        }
    }
}
