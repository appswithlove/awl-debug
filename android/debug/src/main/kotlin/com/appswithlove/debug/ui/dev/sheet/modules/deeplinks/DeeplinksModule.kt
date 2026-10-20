package com.appswithlove.debug.ui.dev.sheet.modules.deeplinks

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.api.DeeplinkItem
import com.appswithlove.debug.ui.component.DevButtonRow
import com.appswithlove.debug.ui.component.DevEmptyState
import com.appswithlove.debug.ui.component.DevGroupLabel
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevOutlinedTextField
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme

/**
 * Quick field plus the app's predefined and the testers' saved deeplinks. [onFire] returns `false`
 * when no screen of the app handles the link.
 */
@Composable
internal fun DeeplinksModule(
    predefined: List<DeeplinkItem>,
    saved: List<DeeplinkItem>,
    onFire: (String) -> Boolean,
    onSave: (DeeplinkItem) -> Unit,
    onDelete: (DeeplinkItem) -> Unit,
    onOpen: (DeeplinkItem) -> Unit,
    modifier: Modifier = Modifier,
) {
    var deeplinkText by rememberSaveable { mutableStateOf("") }
    var deeplinkError by remember { mutableStateOf<String?>(null) }

    fun validated(): String? = deeplinkText.trim().takeIf(::isValidDeeplink).also {
        if (it == null) deeplinkError = "Invalid deeplink"
    }

    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        DevOutlinedTextField(
            modifier = Modifier.fillMaxWidth(),
            value = deeplinkText,
            placeholder = "Enter deeplink",
            onValueChange = {
                deeplinkText = it
                deeplinkError = null
            },
            onClear = {
                deeplinkText = ""
                deeplinkError = null
            },
            isError = deeplinkError != null,
            errorText = deeplinkError,
        )
        val enabled = deeplinkText.isNotBlank() && deeplinkError == null
        DevButtonRow {
            DevOutlinedButton(
                text = "Fire now",
                enabled = enabled,
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = {
                    validated()?.let { url -> if (!onFire(url)) deeplinkError = "Invalid deeplink" }
                },
            )
            DevOutlinedButton(
                text = "Save",
                enabled = enabled,
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = {
                    validated()?.let { url ->
                        onSave(DeeplinkItem(label = url, url = url))
                        deeplinkText = ""
                    }
                },
            )
        }

        if (predefined.isEmpty() && saved.isEmpty()) {
            DevEmptyState(text = "No deeplinks configured")
        }

        if (predefined.isNotEmpty()) {
            SectionLabel("Predefined")
            predefined.forEach { item ->
                DeeplinkRow(item = item, icon = TablerIcons.Lock, onClick = { onOpen(item) })
                HorizontalDivider()
            }
        }

        if (saved.isNotEmpty()) {
            SectionLabel("Saved")
            saved.forEach { item ->
                SwipeToDelete(onDelete = { onDelete(item) }) {
                    DeeplinkRow(
                        // Swiping is not available with TalkBack; the same action is offered in its actions menu.
                        modifier = Modifier.semantics {
                            customActions = listOf(CustomAccessibilityAction("Delete") { onDelete(item); true })
                        },
                        item = item,
                        icon = TablerIcons.User,
                        onClick = { onOpen(item) },
                    )
                }
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    DevGroupLabel(modifier = Modifier.padding(top = 8.dp), text = text)
}

@Composable
private fun SwipeToDelete(onDelete: () -> Unit, content: @Composable () -> Unit) {
    val state = rememberSwipeToDismissBoxState(
        confirmValueChange = { value ->
            if (value == SwipeToDismissBoxValue.EndToStart) onDelete()
            value == SwipeToDismissBoxValue.EndToStart
        },
    )
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppTheme.colors.error)
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Decorative: the row itself offers "Delete" to TalkBack.
                Icon(imageVector = TablerIcons.Trash, contentDescription = null, tint = MaterialTheme.colorScheme.onError)
            }
        },
    ) {
        content()
    }
}

@Composable
private fun DeeplinkRow(item: DeeplinkItem, icon: ImageVector, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(AppTheme.colors.background)
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            modifier = Modifier.size(18.dp),
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = item.label,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = item.url,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun DeeplinksModulePreview() {
    DevTheme {
        DeeplinksModule(
            predefined = listOf(DeeplinkItem(label = "Home", url = "myapp://home")),
            saved = listOf(DeeplinkItem(label = "myapp://profile/123", url = "myapp://profile/123")),
            onFire = { true },
            onSave = {},
            onDelete = {},
            onOpen = {},
        )
    }
}
