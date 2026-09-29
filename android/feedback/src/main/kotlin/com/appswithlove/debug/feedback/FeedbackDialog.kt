package com.appswithlove.debug.feedback

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import com.appswithlove.debug.feedback.queue.FeedbackQueue
import com.appswithlove.debug.feedback.queue.SubmitResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val MAX_TEXT_LENGTH = 5000
private const val MAX_REPORTER_NAME_LENGTH = 200
private const val MAX_REPORTER_EMAIL_LENGTH = 254

private sealed interface SendState {
    data object Idle : SendState
    data object Sending : SendState
    data class Failed(val error: SendError) : SendState
}

/** Where the input fields are and whether one has focus, read by the touch handler without recomposing. */
private class KeyboardDismissal {
    var origin = Offset.Zero
    var fieldBounds = Rect.Zero
    var fieldFocused = false
    var dismissedByCurrentTouch = false
}

@Composable
internal fun FeedbackDialog(
    config: FeedbackConfig,
    draft: FeedbackDraft,
    onCancel: () -> Unit,
    onSent: () -> Unit,
    onQueued: () -> Unit,
    queue: FeedbackQueue = FeedbackQueue.shared(LocalContext.current),
    reporterStore: ReporterStore = ReporterStore(LocalContext.current),
) {
    val scope = rememberCoroutineScope()
    val markup = remember(draft) { MarkupState() }
    var text by remember(draft) { mutableStateOf("") }
    var sendState by remember(draft) { mutableStateOf<SendState>(SendState.Idle) }
    var speechHint by remember(draft) { mutableStateOf<Int?>(null) }
    val isSending = sendState == SendState.Sending
    val keyboard = remember(draft) { KeyboardDismissal() }
    val savedReporter = remember(draft) { reporterStore.load(fallback = config.reporter) }
    var isEditingReporter by remember(draft) { mutableStateOf(savedReporter == null) }
    var reporterName by remember(draft) { mutableStateOf(savedReporter?.name.orEmpty()) }
    var reporterEmail by remember(draft) { mutableStateOf(savedReporter?.email.orEmpty()) }
    val isEmailValid = reporterEmail.isBlank() || reporterEmail.trim().isValidEmail()
    val isReporterValid = reporterName.isNotBlank() && isEmailValid

    val speech = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        when (result.resultCode) {
            Activity.RESULT_OK -> {
                val spoken = result.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull().orEmpty()
                if (spoken.isNotBlank()) text = listOf(text.trimEnd(), spoken).filter { it.isNotEmpty() }.joinToString(" ").take(MAX_TEXT_LENGTH)
                speechHint = null
            }
            Activity.RESULT_CANCELED -> Unit
            else -> speechHint = R.string.feedback_speech_failed
        }
    }

    fun dictate() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        try {
            speech.launch(intent)
        } catch (_: ActivityNotFoundException) {
            speechHint = R.string.feedback_speech_unavailable
        }
    }

    fun send() {
        sendState = SendState.Sending
        val reporter = FeedbackReporter(name = reporterName.trim(), email = reporterEmail.trim().ifEmpty { null })
        if (isEditingReporter) {
            reporterStore.save(reporter)
            isEditingReporter = false
        }
        scope.launch {
            val image = withContext(Dispatchers.Default) {
                encodeMarkedScreenshot(draft.screenshot.asAndroidBitmap(), markup.marks.toList())
            }
            val report = FeedbackReport(
                idempotencyKey = draft.idempotencyKey,
                endpoint = config.endpoint,
                appKey = config.appKey,
                text = text.trim(),
                metadataJson = draft.metadataJson(reporter),
                parts = listOf(FeedbackPart("screenshot", image.fileName, image.mimeType, image.bytes)),
            )
            when (val result = queue.submit(report)) {
                SubmitResult.Sent -> onSent()
                SubmitResult.Queued -> onQueued()
                is SubmitResult.Failed -> sendState = SendState.Failed(result.error)
            }
        }
    }

    Dialog(
        onDismissRequest = { if (!isSending) onCancel() },
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
            dismissOnClickOutside = false,
        ),
    ) {
        val darkTheme = isSystemInDarkTheme()
        val view = LocalView.current
        // The dialog is its own window with its own focus owner; the host's focus manager would not reach the text field.
        val focusManager = LocalFocusManager.current
        SideEffect {
            // The dialog draws edge to edge; keep the system bar icons readable on its surface.
            (view.parent as? DialogWindowProvider)?.window?.let { window ->
                WindowCompat.getInsetsController(window, view).apply {
                    isAppearanceLightStatusBars = !darkTheme
                    isAppearanceLightNavigationBars = !darkTheme
                }
            }
        }
        MaterialTheme(colorScheme = if (darkTheme) darkColorScheme() else lightColorScheme()) {
            Surface(modifier = Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .onGloballyPositioned { keyboard.origin = it.positionInRoot() }
                        .pointerInput(keyboard) {
                            // Any touch outside the input fields closes the keyboard; it still reaches its target,
                            // except the markup canvas, which ignores it (see isDismissingKeyboard).
                            awaitEachGesture {
                                val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
                                keyboard.dismissedByCurrentTouch = keyboard.fieldFocused && !keyboard.fieldBounds.contains(down.position + keyboard.origin)
                                if (keyboard.dismissedByCurrentTouch) focusManager.clearFocus()
                            }
                        }
                        .safeDrawingPadding()
                        .imePadding()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Header(
                        canSend = text.isNotBlank() && isReporterValid && !isSending,
                        isSending = isSending,
                        isRetry = sendState is SendState.Failed,
                        onCancel = onCancel,
                        onSend = ::send,
                    )
                    MarkupEditor(
                        screenshot = draft.screenshot,
                        state = markup,
                        enabled = !isSending,
                        isDismissingKeyboard = { keyboard.dismissedByCurrentTouch },
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                    )
                    Column(
                        modifier = Modifier
                            .onFocusChanged { keyboard.fieldFocused = it.hasFocus }
                            .onGloballyPositioned { keyboard.fieldBounds = it.boundsInRoot() },
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        OutlinedTextField(
                            value = text,
                            onValueChange = { text = it.take(MAX_TEXT_LENGTH) },
                            enabled = !isSending,
                            label = { Text(stringResource(R.string.feedback_text_label)) },
                            minLines = 2,
                            maxLines = 5,
                            trailingIcon = {
                                IconButton(onClick = ::dictate, enabled = !isSending) {
                                    Icon(painter = painterResource(R.drawable.feedback_ic_mic), contentDescription = stringResource(R.string.feedback_dictate))
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                        )
                        if (isEditingReporter) {
                            ReporterFields(
                                name = reporterName,
                                email = reporterEmail,
                                isEmailValid = isEmailValid,
                                enabled = !isSending,
                                onNameChange = { reporterName = it.take(MAX_REPORTER_NAME_LENGTH) },
                                onEmailChange = { reporterEmail = it.take(MAX_REPORTER_EMAIL_LENGTH) },
                            )
                        } else {
                            SentAs(name = reporterName.trim(), enabled = !isSending, onChange = { isEditingReporter = true })
                        }
                    }
                    speechHint?.let { hint ->
                        Text(text = stringResource(hint), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    (sendState as? SendState.Failed)?.let { failed ->
                        Text(text = failed.error.message(), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }
}

@Composable
private fun Header(
    canSend: Boolean,
    isSending: Boolean,
    isRetry: Boolean,
    onCancel: () -> Unit,
    onSend: () -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = onCancel, enabled = !isSending) {
            Text(stringResource(R.string.feedback_cancel))
        }
        Text(
            text = stringResource(R.string.feedback_title),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.Center,
        )
        if (isSending) {
            Box(modifier = Modifier.padding(horizontal = 24.dp)) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            }
        } else {
            Button(onClick = onSend, enabled = canSend) {
                Text(stringResource(if (isRetry) R.string.feedback_retry else R.string.feedback_send))
            }
        }
    }
}

/** Asked until the tester sent a first report; the name is required, the email optional. */
@Composable
private fun ReporterFields(
    name: String,
    email: String,
    isEmailValid: Boolean,
    enabled: Boolean,
    onNameChange: (String) -> Unit,
    onEmailChange: (String) -> Unit,
) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = name,
            onValueChange = onNameChange,
            enabled = enabled,
            label = { Text(stringResource(R.string.feedback_reporter_prompt)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
            modifier = Modifier.weight(1f),
        )
        OutlinedTextField(
            value = email,
            onValueChange = onEmailChange,
            enabled = enabled,
            label = { Text(stringResource(R.string.feedback_reporter_email)) },
            singleLine = true,
            isError = !isEmailValid,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Done),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun SentAs(name: String, enabled: Boolean, onChange: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = stringResource(R.string.feedback_reporter_sent_as, name),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = onChange, enabled = enabled) {
            Text(stringResource(R.string.feedback_reporter_change))
        }
    }
}

@Composable
private fun SendError.message(): String = when (this) {
    SendError.Unauthorized -> stringResource(R.string.feedback_error_unauthorized)
    SendError.TooLarge -> stringResource(R.string.feedback_error_too_large)
    SendError.UnsupportedMedia -> stringResource(R.string.feedback_error_unsupported_media)
    is SendError.RateLimited -> retryAfterSeconds?.let { stringResource(R.string.feedback_error_rate_limited_seconds, it) }
        ?: stringResource(R.string.feedback_error_rate_limited)
    SendError.Invalid -> stringResource(R.string.feedback_error_invalid)
    SendError.Server -> stringResource(R.string.feedback_error_server)
    SendError.Network -> stringResource(R.string.feedback_error_network)
    SendError.InvalidEndpoint -> stringResource(R.string.feedback_error_invalid_endpoint)
    SendError.Unknown -> stringResource(R.string.feedback_error_unknown)
}
