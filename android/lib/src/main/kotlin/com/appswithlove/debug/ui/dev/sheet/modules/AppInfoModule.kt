package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.ui.component.DevSwitchRow

private const val MISSING_VALUE = "n/a"

@Composable
internal fun AppInfoModule(
    devConfig: DevConfig? = null,
    showVersionOverlay: Boolean = false,
    onShowVersionOverlayChanged: ((Boolean) -> Unit)? = null,
) {
    Column {
        Text(
            modifier = Modifier.semantics { heading() },
            text = "App Info",
            style = MaterialTheme.typography.bodyLarge.copy(
                fontWeight = FontWeight(800),
            ),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(4.dp))
        InfoLine(label = "Version", value = devConfig?.versionName ?: MISSING_VALUE)
        InfoLine(label = "Build", value = devConfig?.versionCode?.toString() ?: MISSING_VALUE)
        InfoLine(label = "Flavor", value = devConfig?.flavor ?: MISSING_VALUE)
        InfoLine(label = "Build Type", value = devConfig?.buildType ?: MISSING_VALUE)
        devConfig?.customParams?.forEach { (key, value) ->
            InfoLine(label = key, value = value)
        }
        if (devConfig != null && onShowVersionOverlayChanged != null) {
            DevSwitchRow(
                text = "Show version overlay",
                checked = showVersionOverlay,
                onCheckedChange = onShowVersionOverlayChanged,
            )
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
