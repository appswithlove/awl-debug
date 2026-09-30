package com.appswithlove.debug.ui.dev.sheet.modules.accessibility

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevSectionTitle
import com.appswithlove.debug.ui.component.DevSlider
import com.appswithlove.debug.ui.component.DevSwitchRow
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Font size and appearance overrides for the app content. With [AccessibilitySettings.useSystemFontScale]
 * on (the default) the host content keeps the system accessibility setting untouched.
 */
@Composable
internal fun AccessibilityModule(
    modifier: Modifier = Modifier,
    systemFontScale: Float,
    settings: AccessibilitySettings,
    onSettingsChanged: (AccessibilitySettings) -> Unit,
) {
    val context = LocalContext.current
    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SectionTitle("Font size")
        DevSwitchRow(
            text = "Use system font size (${systemFontScale.asPercent()})",
            checked = settings.useSystemFontScale,
            onCheckedChange = { useSystem ->
                onSettingsChanged(
                    settings.copy(
                        useSystemFontScale = useSystem,
                        fontScale = if (useSystem) settings.fontScale else systemFontScale,
                    )
                )
            },
        )

        if (!settings.useSystemFontScale) {
            OptionChips(
                options = FONT_SCALE_PRESETS,
                label = { it.first },
                isSelected = { abs(it.second - settings.fontScale) < 0.001f },
                onSelected = { onSettingsChanged(settings.copy(fontScale = it.second)) },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Font size",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = settings.fontScale.asPercent(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            DevSlider(
                value = settings.fontScale,
                onValueChange = { onSettingsChanged(settings.copy(fontScale = it)) },
                valueRange = 0.5f..2.0f,
                steps = 5,
            )

            DevOutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                text = "Reset to 100%",
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = { onSettingsChanged(settings.copy(fontScale = 1f)) },
            )
        }

        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
        SectionTitle("Appearance")
        OptionChips(
            options = Appearance.entries,
            label = { it.label },
            isSelected = { it == settings.appearance },
            onSelected = { onSettingsChanged(settings.copy(appearance = it)) },
        )

        Text(
            text = "Applies to app content inside the debug container only. " +
                "On Android 12 and later, the appearance applies to the whole app.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
        SectionTitle("How to scale on device")
        Text(
            text = "Settings → Display → Display size and text",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            text = "Open settings",
            contentColor = MaterialTheme.colorScheme.onSurface,
            onClick = {
                val intent = Intent(Settings.ACTION_DISPLAY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    context.startActivity(intent)
                } catch (_: ActivityNotFoundException) {
                    context.startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
            },
        )
    }
}

@Composable
private fun SectionTitle(text: String) {
    DevSectionTitle(text = text)
}

@Composable
private fun <T> OptionChips(
    options: List<T>,
    label: (T) -> String,
    isSelected: (T) -> Boolean,
    onSelected: (T) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEach { option ->
            FilterChip(
                selected = isSelected(option),
                onClick = { onSelected(option) },
                label = { Text(text = label(option), style = MaterialTheme.typography.labelMedium) },
                colors = FilterChipDefaults.filterChipColors().copy(
                    selectedContainerColor = MaterialTheme.colorScheme.onSurface,
                    selectedLabelColor = AppTheme.colors.background,
                ),
            )
        }
    }
}

private fun Float.asPercent(): String = "${(this * 100).roundToInt()}%"

@Preview(showBackground = true)
@Composable
private fun AccessibilityModulePreview() {
    DevTheme {
        AccessibilityModule(
            systemFontScale = 1.3f,
            settings = AccessibilitySettings(useSystemFontScale = false, appearance = Appearance.Dark),
            onSettingsChanged = {},
        )
    }
}
