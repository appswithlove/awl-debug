package com.appswithlove.debug.ui.dev.sheet.modules

import android.os.Build
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.api.DevConfig
import com.appswithlove.debug.ui.component.DevSwitchRow
import com.appswithlove.debug.ui.component.icons.TablerIcons

private const val MISSING_VALUE = "n/a"

/**
 * App Info on the start page. With [onExpandedChange] the header collapses it to one summary line
 * ([appInfoSummary]); the version overlay switch is hidden while collapsed.
 */
@Composable
internal fun AppInfoModule(
    devConfig: DevConfig? = null,
    showVersionOverlay: Boolean = false,
    onShowVersionOverlayChanged: ((Boolean) -> Unit)? = null,
    isExpanded: Boolean = true,
    onExpandedChange: ((Boolean) -> Unit)? = null,
) {
    Column {
        AppInfoHeader(isExpanded = isExpanded, onExpandedChange = onExpandedChange)
        if (isExpanded) {
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
        } else {
            val context = LocalContext.current
            val appName = remember(context) { context.applicationInfo.loadLabel(context.packageManager).toString() }
            Text(
                text = appInfoSummary(appName, devConfig, Build.VERSION.RELEASE),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

/** The whole row toggles; TalkBack reads one heading with its state and the action. */
@Composable
private fun AppInfoHeader(isExpanded: Boolean, onExpandedChange: ((Boolean) -> Unit)?) {
    val toggleModifier = if (onExpandedChange != null) {
        Modifier
            .clickable(role = Role.Button, onClickLabel = if (isExpanded) "Collapse" else "Expand") {
                onExpandedChange(!isExpanded)
            }
            .heightIn(min = 48.dp)
    } else {
        Modifier
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(toggleModifier)
            .semantics(mergeDescendants = true) {
                heading()
                if (onExpandedChange != null) stateDescription = if (isExpanded) "Expanded" else "Collapsed"
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            modifier = Modifier.weight(1f),
            text = "App Info",
            style = MaterialTheme.typography.bodyLarge.copy(
                fontWeight = FontWeight(800),
            ),
            color = MaterialTheme.colorScheme.onSurface,
        )
        if (onExpandedChange != null) {
            Spacer(modifier = Modifier.width(8.dp))
            Icon(
                imageVector = if (isExpanded) TablerIcons.ChevronUp else TablerIcons.ChevronDown,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** Collapsed App Info: "MyApp 1.0 (42) · Android 15 · prod debug". */
internal fun appInfoSummary(appName: String, devConfig: DevConfig?, androidVersion: String): String =
    listOfNotNull(
        listOfNotNull(appName.ifBlank { null }, devConfig?.let { "${it.versionName} (${it.versionCode})" })
            .joinToString(" ")
            .ifBlank { null },
        "Android $androidVersion",
        devConfig?.let { "${it.flavor} ${it.buildType}".trim() }?.ifBlank { null },
    ).joinToString(" · ")

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
