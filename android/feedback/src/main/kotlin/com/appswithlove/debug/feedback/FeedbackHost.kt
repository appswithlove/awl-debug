package com.appswithlove.debug.feedback

import android.content.Context
import android.hardware.SensorManager
import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.util.Date

private const val LOG_TAG = "Feedback"

/** Everything captured at the moment the tester starts a report. */
internal class FeedbackDraft(
    val screenshot: ImageBitmap,
    val metadataJson: String,
)

internal class FeedbackController(
    private val scope: CoroutineScope,
    private val layer: GraphicsLayer,
    private val config: () -> FeedbackConfig?,
) {
    val isConfigured: Boolean get() = config() != null
    var draft: FeedbackDraft? by mutableStateOf(null)
        private set

    fun start() {
        val currentConfig = config() ?: return
        if (draft != null) return
        val extra = currentConfig.extraMetadata()
        val timestamp = Date()
        scope.launch {
            if (layer.size.width == 0 || layer.size.height == 0) {
                Log.w(LOG_TAG, "Nothing recorded yet, cannot take a screenshot")
                return@launch
            }
            draft = FeedbackDraft(
                screenshot = layer.toImageBitmap(),
                metadataJson = buildMetadataJson(currentConfig, DeviceInfo.current(), extra, timestamp),
            )
        }
    }

    fun finish() {
        draft = null
    }
}

internal val LocalFeedbackController = staticCompositionLocalOf<FeedbackController?> { null }

/**
 * Records [content] so a report can attach a screenshot of it, and hosts the feedback screen.
 *
 * Place it around the app content and outside of overlays that must not show up in the screenshot.
 * Dialogs, popups and bottom sheets draw in their own windows and are never part of the screenshot.
 * Shaking the device starts a report too, unless [FeedbackConfig.shakeToReport] is off.
 * With a `null` [config] the content is passed through and [FeedbackLauncher] reports that feedback is not configured.
 */
@Composable
fun FeedbackHost(config: FeedbackConfig?, content: @Composable () -> Unit) {
    val currentConfig by rememberUpdatedState(config)
    val layer = rememberGraphicsLayer()
    val scope = rememberCoroutineScope()
    val controller = remember(layer) { FeedbackController(scope, layer) { currentConfig } }
    val recording = if (config != null) {
        Modifier.drawWithContent {
            layer.record { this@drawWithContent.drawContent() }
            drawLayer(layer)
        }
    } else {
        Modifier
    }
    if (config?.shakeToReport == true) {
        ShakeToReport(onShake = controller::start)
    }
    CompositionLocalProvider(LocalFeedbackController provides controller) {
        Box(modifier = recording, propagateMinConstraints = true) {
            content()
        }
        val draft = controller.draft
        if (config != null && draft != null) {
            val appContext = LocalContext.current.applicationContext
            val sentMessage = stringResource(R.string.feedback_sent)
            FeedbackDialog(
                config = config,
                draft = draft,
                onCancel = controller::finish,
                onSent = {
                    // Close first, then confirm over the app; the application context outlives the dialog.
                    controller.finish()
                    Toast.makeText(appContext, sentMessage, Toast.LENGTH_SHORT).show()
                },
            )
        }
    }
}

/** Listens for shakes only while the host lifecycle is resumed. */
@Composable
private fun ShakeToReport(onShake: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnShake by rememberUpdatedState(onShake)
    DisposableEffect(context, lifecycleOwner) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val detector = sensorManager?.let { ShakeDetector(it) { currentOnShake() } }
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> detector?.start()
                Lifecycle.Event.ON_PAUSE -> detector?.stop()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            detector?.stop()
        }
    }
}

/**
 * Entry that starts a report, e.g. as a DevSheet custom module. Must sit inside a [FeedbackHost];
 * the screenshot is taken the moment it is tapped.
 */
@Composable
fun FeedbackLauncher(modifier: Modifier = Modifier) {
    val controller = LocalFeedbackController.current
    val enabled = controller?.isConfigured == true
    Text(
        text = stringResource(if (enabled) R.string.feedback_entry else R.string.feedback_not_configured),
        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.ExtraBold),
        color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier
            .fillMaxWidth()
            .clickable(enabled = enabled) { controller?.start() }
            .padding(vertical = 6.dp),
    )
}
