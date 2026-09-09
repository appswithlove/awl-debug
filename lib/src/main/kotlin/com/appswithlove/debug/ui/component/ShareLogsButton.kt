package com.appswithlove.debug.ui.component

import android.content.Context
import android.content.Intent
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
import androidx.core.content.FileProvider
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.dev.log.LogHistory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.charset.StandardCharsets

@Composable
fun ShareLogsButton(
    modifier: Modifier = Modifier,
    logHistory: LogHistory
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val filename = "android-logs.txt"

    DevOutlinedButton(
        modifier = modifier,
        text = "Export Logs",
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
            scope.launch(Dispatchers.IO) {
                try {
                    val logs = logHistory.logEntries.value
                    val logFile = File(context.filesDir, filename)

                    context.openFileOutput(logFile.name, Context.MODE_PRIVATE)
                        .use { outputStream ->
                            outputStream.writer(StandardCharsets.UTF_8).use { writer ->
                                logs.forEach { logEntry ->
                                    writer.write(logEntry.toExportString())
                                    writer.write("\n")
                                    writer.write("\n")
                                }
                            }
                        }

                    val authority = "${context.packageName}.fileprovider"
                    val logUri = FileProvider.getUriForFile(context, authority, logFile)

                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_STREAM, logUri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }

                    withContext(Dispatchers.Main) {
                        context.startActivity(
                            Intent.createChooser(shareIntent, "Share Logs")
                        )
                    }
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
