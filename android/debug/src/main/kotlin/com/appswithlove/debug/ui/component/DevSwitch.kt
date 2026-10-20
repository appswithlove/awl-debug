package com.appswithlove.debug.ui.component

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.theme.AppTheme

@Composable
internal fun DevSwitch(
    checked: Boolean,
    onCheckedChange: ((Boolean) -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Switch(
        modifier = modifier,
        checked = checked,
        onCheckedChange = onCheckedChange,
        colors = SwitchDefaults.colors().copy(
            checkedThumbColor = AppTheme.colors.background,
            uncheckedThumbColor = AppTheme.colors.background,
            checkedTrackColor = MaterialTheme.colorScheme.onSurface,
            uncheckedTrackColor = AppTheme.colors.iconSubtle,
            checkedBorderColor = MaterialTheme.colorScheme.onSurface,
            uncheckedBorderColor = AppTheme.colors.iconSubtle,
        ),
    )
}

/** A labelled switch; the whole row toggles, so TalkBack reads the label together with the state. */
@Composable
internal fun DevSwitchRow(
    text: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .toggleable(value = checked, role = Role.Switch, onValueChange = onCheckedChange),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            modifier = Modifier
                .weight(1f)
                .padding(end = 12.dp),
            text = text,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
        )
        DevSwitch(checked = checked, onCheckedChange = null)
    }
}
