package com.appswithlove.debug.ui.component

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.appswithlove.debug.ui.theme.AppTheme

@Composable
fun DevSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
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
