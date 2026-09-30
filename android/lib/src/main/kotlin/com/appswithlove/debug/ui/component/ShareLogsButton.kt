package com.appswithlove.debug.ui.component

import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.dev.log.LogHistory
import kotlinx.coroutines.launch

@Composable
internal fun ShareLogsButton(
    modifier: Modifier = Modifier,
    logHistory: LogHistory
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val filename = "android-logs.txt"

    DevOutlinedButton(
        modifier = modifier,
        text = "Export logs",
        leadingIcon = {
            Icon(
                modifier = Modifier.size(18.dp),
                imageVector = TablerIcons.Share,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface
            )
        },
        contentColor = MaterialTheme.colorScheme.onSurface,
        onClick = {
            scope.launch {
                try {
                    val text = logHistory.filteredSnapshot().joinToString(separator = "") { "${it.toExportString()}\n\n" }
                    shareTextFile(context, filename, text, chooserTitle = "Share logs")
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    )
}

@Preview(showBackground = true)
@Composable
private fun ShareLogsButtonPreview() {
    ShareLogsButton(
        modifier = Modifier.padding(horizontal = 4.dp),
        logHistory = LogHistory.Preview,
    )
}
