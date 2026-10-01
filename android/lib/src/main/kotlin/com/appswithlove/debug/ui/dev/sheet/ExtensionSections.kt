package com.appswithlove.debug.ui.dev.sheet

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.appswithlove.debug.R
import com.appswithlove.debug.api.DevTrigger
import com.appswithlove.debug.api.extension.DevExtensionItem
import com.appswithlove.debug.api.extension.DevExtensionSection
import com.appswithlove.debug.api.extension.DevTextStyle
import com.appswithlove.debug.ui.component.DevSwitchRow

/**
 * Sections of other libraries, each after a divider. A section without items is hidden.
 *
 * @param onLink Runs a [DevExtensionItem.Link] action; the panel closes first.
 * @param onCopy Copies a [DevExtensionItem.Text.copyValue] to the clipboard.
 */
@Composable
internal fun ColumnScope.ExtensionSections(
    sections: List<DevExtensionSection>,
    onLink: (action: () -> Unit) -> Unit,
    onCopy: (String) -> Unit,
) {
    sections.forEach { section ->
        key(section.id) {
            val items by section.items.collectAsStateWithLifecycle()
            if (items.isNotEmpty()) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    items.forEach { item -> ExtensionItem(item, onLink, onCopy) }
                }
            }
        }
    }
}

/** Triggers that registered sections handle themselves. */
internal fun List<DevExtensionSection>.claimedTriggers(): Set<DevTrigger> = flatMapTo(mutableSetOf()) { it.claimedTriggers }

@Composable
private fun ExtensionItem(item: DevExtensionItem, onLink: (() -> Unit) -> Unit, onCopy: (String) -> Unit) {
    when (item) {
        is DevExtensionItem.Title -> Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                modifier = Modifier
                    .weight(1f)
                    .semantics { heading() },
                text = item.text,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight(800)),
                color = MaterialTheme.colorScheme.onSurface,
            )
            item.action?.let { action ->
                TextButton(onClick = action.onClick, enabled = action.enabled) { Text(action.text) }
            }
        }

        is DevExtensionItem.Text -> {
            val copyValue = item.copyValue
            Text(
                modifier = if (copyValue == null) {
                    Modifier
                } else {
                    Modifier
                        .fillMaxWidth()
                        .clickable(onClickLabel = "Copy") { onCopy(copyValue) }
                        .padding(vertical = 4.dp)
                },
                text = item.text,
                style = if (item.style == DevTextStyle.Monospace) {
                    MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace)
                } else {
                    LocalTextStyle.current
                },
                color = item.style.color(),
            )
        }

        is DevExtensionItem.Switch -> DevSwitchRow(text = item.text, checked = item.checked, onCheckedChange = item.onCheckedChange)

        is DevExtensionItem.Link -> Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(role = Role.Button) { onLink(item.onClick) }
                .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.text,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight(800)),
                    color = MaterialTheme.colorScheme.onSurface,
                )
                item.badge?.let { badge ->
                    Text(
                        text = badge,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Icon(
                painter = painterResource(R.drawable.ic_chevron_right),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }
}

@Composable
private fun DevTextStyle.color(): Color = when (this) {
    DevTextStyle.Primary -> MaterialTheme.colorScheme.onSurface
    DevTextStyle.Secondary, DevTextStyle.Monospace -> MaterialTheme.colorScheme.onSurfaceVariant
    DevTextStyle.Error -> MaterialTheme.colorScheme.error
}
