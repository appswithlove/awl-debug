package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.ui.component.DevSwitch

@Composable
internal fun AppInfoModule(
    devConfig: DevConfig? = null,
    showVersionOverlay: Boolean = false,
    onShowVersionOverlayChanged: ((Boolean) -> Unit)? = null,
) {
    Column {
        Text(
            text = "App Info",
            style = MaterialTheme.typography.bodyLarge.copy(
                fontWeight = FontWeight(800),
            ),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(4.dp))
        InfoLine(label = "Version", value = devConfig?.versionName ?: "No information")
        InfoLine(label = "Build", value = devConfig?.versionCode?.toString() ?: "No information")
        InfoLine(label = "Flavor", value = devConfig?.flavor ?: "No information")
        InfoLine(label = "Build Type", value = devConfig?.buildType ?: "No information")
        devConfig?.customParams?.forEach { (key, value) ->
            InfoLine(label = key, value = value)
        }
        if (devConfig != null && onShowVersionOverlayChanged != null) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    modifier = Modifier.weight(1f),
                    text = "Show version overlay",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                DevSwitch(checked = showVersionOverlay, onCheckedChange = onShowVersionOverlayChanged)
            }
        }
    }
}

@Composable
private fun InfoLine(label: String, value: String) {
    Text(
        text = buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("$label: ") }
            append(value)
        },
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurface,
    )
}
