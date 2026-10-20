package com.appswithlove.debug.ui.dev.sheet.modules

import android.os.Handler
import android.os.Looper
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
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

/** Asks for confirmation, then crashes with [crash]; by default one of the [AwlDebugTestCrash] crashes. */
@Composable
internal fun TestCrashesModule(crash: (TestCrash) -> Unit = ::crashAfterDialogClosed) {
    var pendingCrash by remember { mutableStateOf<TestCrash?>(null) }

    Column(
        modifier = Modifier.padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TestCrash.entries.forEach { testCrash ->
            DevOutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                contentColor = AppTheme.colors.error,
                text = testCrash.label,
                leadingIcon = {
                    Icon(
                        modifier = Modifier.size(18.dp),
                        imageVector = TablerIcons.AlertTriangle,
                        contentDescription = null,
                        tint = AppTheme.colors.error
                    )
                },
                onClick = { pendingCrash = testCrash },
            )
        }
    }

    pendingCrash?.let { testCrash ->
        AlertDialog(
            onDismissRequest = { pendingCrash = null },
            title = { Text("Crash the app now?") },
            confirmButton = {
                TextButton(onClick = {
                    pendingCrash = null
                    crash(testCrash)
                }) { Text("Crash", color = AppTheme.colors.error) }
            },
            dismissButton = {
                TextButton(onClick = { pendingCrash = null }) { Text("Cancel") }
            },
        )
    }
}

internal enum class TestCrash(val label: String) {
    Runtime("Simulate crash - Runtime exception"),
    IndexOutOfBounds("Simulate crash - Index out of bounds"),
}

/** Posted to the main thread, so the dialog closes first and the stack trace starts in [AwlDebugTestCrash]. */
private fun crashAfterDialogClosed(testCrash: TestCrash) {
    Handler(Looper.getMainLooper()).post {
        when (testCrash) {
            TestCrash.Runtime -> AwlDebugTestCrash.runtime()
            TestCrash.IndexOutOfBounds -> AwlDebugTestCrash.indexOutOfBounds()
        }
    }
}

/** Named entry points, so crash reports show where a test crash came from. */
internal object AwlDebugTestCrash {
    /** Same message on both platforms. */
    fun runtime(): Nothing = throw RuntimeException("AWL Debug test crash")

    /** Reads index 0 of an empty array, like an implicit crash in app code. */
    fun indexOutOfBounds(): Int = emptyArray<Int>()[0]
}
