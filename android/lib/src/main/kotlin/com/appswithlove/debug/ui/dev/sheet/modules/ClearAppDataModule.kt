package com.appswithlove.debug.ui.dev.sheet.modules

import android.app.ActivityManager
import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme

/** Asks for confirmation, then calls [onClear], usually [clearAppData]. */
@Composable
internal fun ClearAppDataModule(onClear: () -> Unit) {
    var showConfirmation by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.padding(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "All app data, including AWL Debug settings, will be deleted and the app will close.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
        )
        DevOutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            contentColor = AppTheme.colors.error,
            text = "Clear app data",
            leadingIcon = {
                Icon(
                    modifier = Modifier.size(18.dp),
                    imageVector = TablerIcons.TrashX,
                    contentDescription = null,
                    tint = AppTheme.colors.error,
                )
            },
            onClick = { showConfirmation = true },
        )
    }

    if (showConfirmation) {
        AlertDialog(
            onDismissRequest = { showConfirmation = false },
            title = { Text("Clear app data?") },
            text = { Text("All app data, including AWL Debug settings, will be deleted and the app will close.") },
            confirmButton = {
                TextButton(onClick = {
                    showConfirmation = false
                    onClear()
                }) { Text("Clear", color = AppTheme.colors.error) }
            },
            dismissButton = {
                TextButton(onClick = { showConfirmation = false }) { Text("Cancel") }
            },
        )
    }
}

/** Deletes all data of the app, including runtime permissions, and ends the process. */
internal fun clearAppData(context: Context) {
    (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).clearApplicationUserData()
}
