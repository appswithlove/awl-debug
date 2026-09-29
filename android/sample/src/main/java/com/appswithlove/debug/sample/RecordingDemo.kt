package com.appswithlove.debug.sample

import android.app.Activity
import android.os.Handler
import android.os.HandlerThread
import android.text.InputType
import android.util.Log
import android.view.FrameMetrics
import android.widget.EditText
import android.widget.TextView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.appswithlove.debug.ui.dev.recording.awlDebugMasked

/** Fields and a list to try the Screen Recording module: masked areas appear black in recorded frames. */
@Composable
internal fun RecordingDemo(modifier: Modifier = Modifier) {
    var password by rememberSaveable { mutableStateOf("") }
    Column(modifier = modifier.width(280.dp)) {
        OutlinedTextField(
            modifier = Modifier.fillMaxWidth().testTag("composePassword"),
            value = password,
            onValueChange = { password = it },
            label = { Text("Password (Compose)") },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
        )
        AndroidView(
            modifier = Modifier.fillMaxWidth(),
            factory = { context ->
                EditText(context).apply {
                    hint = "Password (View)"
                    inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                }
            },
        )
        Text(
            modifier = Modifier
                .padding(vertical = 4.dp)
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(8.dp)
                .awlDebugMasked(),
            text = "IBAN CH00 0000 0000 (masked Compose)",
        )
        AndroidView(
            factory = { context ->
                TextView(context).apply {
                    text = "Card 4000 0000 (masked View)"
                    awlDebugMasked = true
                }
            },
        )
        LazyColumn(modifier = Modifier.fillMaxWidth().height(160.dp)) {
            items(count = 200) { index ->
                Box(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) { Text("Row $index") }
            }
        }
    }
}

/** Logs frames that take longer than 100 ms, to check the recorder's main-thread cost while scrolling. */
internal fun Activity.logSlowFrames() {
    window.addOnFrameMetricsAvailableListener({ _, metrics, _ ->
        val totalMs = metrics.getMetric(FrameMetrics.TOTAL_DURATION) / 1_000_000
        if (totalMs > SLOW_FRAME_MS) Log.w("AwlSampleFrames", "Slow frame: $totalMs ms")
    }, Handler(HandlerThread("frame-metrics").apply { start() }.looper))
}

private const val SLOW_FRAME_MS = 100L
