package com.appswithlove.debug.ui.dev.sheet.modules.deeplinks

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.api.DeeplinkItem
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevSectionTitle
import com.appswithlove.debug.ui.theme.AppTheme

private val DELAYS_SECONDS = listOf(5, 10, 30)

/** Fires [item] right away or schedules it as a notification for cold start tests. */
@Composable
internal fun DeeplinkDetailModule(
    item: DeeplinkItem,
    onFire: () -> Boolean,
    onSchedule: (delaySeconds: Int) -> ScheduleResult,
    onScheduled: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    var delaySeconds by rememberSaveable { mutableIntStateOf(DELAYS_SECONDS.first()) }
    var message by remember { mutableStateOf<String?>(null) }
    var isError by remember { mutableStateOf(false) }
    var showOpenSettings by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = item.label,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = item.url,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
        SectionTitle("While app is active")
        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            text = "Fire now",
            contentColor = MaterialTheme.colorScheme.onSurface,
            onClick = {
                if (!onFire()) {
                    message = "Invalid deeplink"
                    isError = true
                }
            },
        )

        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
        SectionTitle("Cold start (via notification)")
        Text(
            text = "Delay",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            DELAYS_SECONDS.forEach { seconds ->
                FilterChip(
                    selected = seconds == delaySeconds,
                    onClick = { delaySeconds = seconds },
                    label = { Text(text = "$seconds s", style = MaterialTheme.typography.labelMedium) },
                    colors = FilterChipDefaults.filterChipColors().copy(
                        selectedContainerColor = MaterialTheme.colorScheme.onSurface,
                        selectedLabelColor = AppTheme.colors.background,
                    ),
                )
            }
        }
        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            text = "Schedule & close app",
            contentColor = MaterialTheme.colorScheme.onSurface,
            onClick = {
                when (onSchedule(delaySeconds)) {
                    ScheduleResult.Scheduled -> {
                        message = "Scheduled in ${delaySeconds}s. You can close the app now."
                        isError = false
                        showOpenSettings = false
                        onScheduled()
                    }
                    ScheduleResult.MissingPermission -> {
                        message = "Notification permission is required to fire deeplinks with delay."
                        isError = true
                        showOpenSettings = true
                    }
                    ScheduleResult.Failed -> {
                        message = "Failed to schedule notification."
                        isError = true
                        showOpenSettings = false
                    }
                }
            },
        )
        Text(
            text = "A local notification will fire after the delay. Close the app after scheduling to test cold start. " +
                "Note: may be suppressed in Focus mode.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        message?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = if (isError) AppTheme.colors.error else AppTheme.colors.positive,
            )
        }
        if (showOpenSettings) {
            DevOutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                text = "Open app settings",
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = {
                    context.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                },
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    DevSectionTitle(text = text)
}
