package com.appswithlove.debug.ui.dev.sheet.modules.accessibility

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevSlider
import com.appswithlove.debug.ui.component.DevSwitch
import com.appswithlove.debug.ui.theme.DevTheme
import kotlin.math.roundToInt

/**
 * Font scale controls. With [useSystemFontScale] on (the default) the host content keeps the
 * system accessibility setting untouched. Off, [fontScale] is applied as an absolute value.
 */
@Composable
fun AccessibilityModule(
    modifier: Modifier = Modifier,
    systemFontScale: Float,
    useSystemFontScale: Boolean,
    onUseSystemFontScaleChanged: (Boolean) -> Unit,
    fontScale: Float,
    onFontScaleChanged: (Float) -> Unit,
) {
    Column(
        modifier = modifier.padding(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Use system font scale (${systemFontScale.asPercent()})",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            DevSwitch(
                checked = useSystemFontScale,
                onCheckedChange = onUseSystemFontScaleChanged,
            )
        }

        if (!useSystemFontScale) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Font Scale",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = fontScale.asPercent(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            DevSlider(
                value = fontScale,
                onValueChange = onFontScaleChanged,
                valueRange = 0.5f..2.0f,
                steps = 5,
            )

            DevOutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                text = "Reset to 100%",
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = { onFontScaleChanged(1f) },
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
            useSystemFontScale = false,
            onUseSystemFontScaleChanged = {},
            fontScale = 1f,
            onFontScaleChanged = {},
        )
    }
}
