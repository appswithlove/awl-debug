package com.appswithlove.debug.ui.dev.sheet.modules.session

import android.content.ClipData
import kotlinx.coroutines.CancellationException
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.Canvas
import android.os.PersistableBundle
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.api.session.SessionProvider
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevOutlinedTextField
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch

@Composable
internal fun SessionDetailModule(
    modifier: Modifier = Modifier,
    sessionManager: SessionManager,
) {
    val states by sessionManager.states.collectAsState()
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboard.current
    val revealedTokens = remember { mutableStateMapOf<String, Boolean>() }

    val editTarget = remember { mutableStateOf<SessionManager.ProviderState?>(null) }
    val deleteTarget = remember { mutableStateOf<SessionManager.ProviderState?>(null) }
    // Per provider label: the action that is running, and the last error.
    val runningActions = remember { mutableStateMapOf<String, SessionAction>() }
    val actionErrors = remember { mutableStateMapOf<String, String>() }

    fun runAction(state: SessionManager.ProviderState, action: SessionAction, block: suspend () -> Unit) {
        val label = state.provider.label
        if (label in runningActions) return
        runningActions[label] = action
        actionErrors.remove(label)
        scope.launch {
            try {
                block()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                actionErrors[label] = "Action failed: ${e.message ?: e::class.simpleName}"
            } finally {
                runningActions.remove(label)
            }
        }
    }

    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (states.isEmpty()) {
            SessionSetupHint(
                onCopy = {
                    scope.launch { clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("Code", SESSION_SETUP_SNIPPET))) }
                },
            )
        }
        states.forEachIndexed { index, state ->
            ProviderCard(
                state = state,
                isRevealed = revealedTokens[state.provider.label] == true,
                onRevealToggle = {
                    revealedTokens[state.provider.label] =
                        revealedTokens[state.provider.label] != true
                },
                runningAction = runningActions[state.provider.label],
                error = actionErrors[state.provider.label],
                onCopy = {
                    val token = state.token ?: return@ProviderCard
                    scope.launch { clipboard.setClipEntry(ClipEntry(sensitiveClip(token))) }
                },
                onEdit = state.provider.onSetToken?.let { { editTarget.value = state } },
                onDelete = state.provider.onSetToken?.let { { deleteTarget.value = state } },
                onInvalidate = if (sessionManager.canInvalidate(state.provider)) {
                    { runAction(state, SessionAction.Invalidate) { sessionManager.invalidate(state) } }
                } else {
                    null
                },
                onLogin = state.provider.onLogin?.let { action ->
                    { runAction(state, SessionAction.Login) { action() } }
                },
                onRefresh = state.provider.onRefresh?.let { action ->
                    { runAction(state, SessionAction.Refresh) { action() } }
                },
                onLogout = state.provider.onLogout?.let { action ->
                    { runAction(state, SessionAction.Logout) { action() } }
                },
            )
            if (index < states.lastIndex) {
                HorizontalDivider()
            }
        }
    }

    editTarget.value?.let { target ->
        EditTokenDialog(
            providerLabel = target.provider.label,
            currentToken = target.token.orEmpty(),
            onConfirm = { newToken ->
                runAction(target, SessionAction.Edit) {
                    sessionManager.setToken(target.provider, newToken.ifBlank { null })
                }
                editTarget.value = null
            },
            onDismiss = { editTarget.value = null },
        )
    }

    deleteTarget.value?.let { target ->
        DeleteTokenDialog(
            providerLabel = target.provider.label,
            onConfirm = {
                runAction(target, SessionAction.Delete) { sessionManager.setToken(target.provider, null) }
                deleteTarget.value = null
            },
            onDismiss = { deleteTarget.value = null },
        )
    }
}

@Composable
private fun ProviderCard(
    state: SessionManager.ProviderState,
    isRevealed: Boolean,
    onRevealToggle: () -> Unit,
    runningAction: SessionAction?,
    error: String?,
    onCopy: () -> Unit,
    onEdit: (() -> Unit)?,
    onDelete: (() -> Unit)?,
    onInvalidate: (() -> Unit)?,
    onLogin: (() -> Unit)?,
    onRefresh: (() -> Unit)?,
    onLogout: (() -> Unit)?,
) {
    val isLoggedIn = state.token != null
    val idle = runningAction == null

    @Composable
    fun ActionButton(action: SessionAction, contentColor: Color, onClick: () -> Unit, icon: ImageVector? = null) {
        DevOutlinedButton(
            text = if (runningAction == action) action.runningLabel else action.label,
            enabled = idle,
            leadingIcon = when {
                runningAction == action -> {
                    { CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = contentColor) }
                }
                icon != null -> {
                    { Icon(imageVector = icon, contentDescription = null, tint = LocalContentColor.current) }
                }
                else -> null
            },
            contentColor = contentColor,
            onClick = onClick,
        )
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = state.provider.label,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold),
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
        }

        LoginStatus(isLoggedIn = isLoggedIn)

        if (isLoggedIn) {
            Spacer(modifier = Modifier.height(4.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.05f),
                        shape = MaterialTheme.shapes.small,
                    )
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = if (isRevealed) state.token else maskToken(state.token),
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onRevealToggle) {
                    Icon(
                        imageVector = if (isRevealed) TablerIcons.EyeOff else TablerIcons.Eye,
                        contentDescription = if (isRevealed) "Hide token" else "Reveal token",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val onSurface = MaterialTheme.colorScheme.onSurface
            val errorColor = AppTheme.colors.error
            if (isLoggedIn) ActionButton(SessionAction.Copy, onSurface, onCopy, TablerIcons.Copy)
            if (onEdit != null) ActionButton(SessionAction.Edit, onSurface, onEdit, TablerIcons.Pencil)
            if (isLoggedIn && onDelete != null) ActionButton(SessionAction.Delete, errorColor, onDelete, TablerIcons.Trash)
            if (isLoggedIn && onInvalidate != null) ActionButton(SessionAction.Invalidate, errorColor, onInvalidate)
            if (!isLoggedIn && onLogin != null) ActionButton(SessionAction.Login, onSurface, onLogin)
            if (isLoggedIn && onRefresh != null) ActionButton(SessionAction.Refresh, onSurface, onRefresh, TablerIcons.Refresh)
            if (isLoggedIn && onLogout != null) ActionButton(SessionAction.Logout, errorColor, onLogout)
        }

        error?.let {
            Text(text = it, style = MaterialTheme.typography.bodySmall, color = AppTheme.colors.error)
        }
    }
}

/** Shown while the app passes no `sessionProviders`: how to add one. */
@Composable
private fun SessionSetupHint(onCopy: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "No session tokens configured",
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = "Add one provider per token source to DevModulesConfig.sessionProviders to inspect the tokens " +
                "here and test login, refresh and logout.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = SESSION_SETUP_SNIPPET,
            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            softWrap = false,
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.05f),
                    shape = MaterialTheme.shapes.small,
                )
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 8.dp),
        )
        DevOutlinedButton(
            text = "Copy code",
            leadingIcon = { Icon(imageVector = TablerIcons.Copy, contentDescription = null, tint = LocalContentColor.current) },
            onClick = onCopy,
        )
    }
}

private val SESSION_SETUP_SNIPPET = """
    DevModulesConfig(
        sessionProviders = listOf(
            PollingSessionProvider(
                label = "Access Token",
            ) { auth.accessToken() },
        ),
    )
""".trimIndent()

@Composable
private fun LoginStatus(isLoggedIn: Boolean) {
    val color = if (isLoggedIn) AppTheme.colors.positive else Color.Gray.copy(alpha = 0.5f)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        Canvas(modifier = Modifier.size(8.dp)) { drawCircle(color = color) }
        Text(
            text = if (isLoggedIn) "Logged in" else "Logged out",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

internal enum class SessionAction(val label: String, val runningLabel: String) {
    Copy("Copy", "Copy"),
    Edit("Edit", "Edit"),
    Delete("Delete", "Delete"),
    Invalidate("Invalidate", "Invalidating…"),
    Login("Login", "Login"),
    Refresh("Refresh", "Refresh"),
    Logout("Logout", "Logout"),
}

/** First 6 and last 4 characters; shorter tokens are fully masked. */
internal fun maskToken(token: String): String =
    if (token.length <= 10) "•".repeat(token.length) else "${token.take(6)}…${token.takeLast(4)}"

/** Marks the clip as sensitive so Android 13+ hides it from the clipboard preview. */
private fun sensitiveClip(token: String): ClipData = ClipData.newPlainText("Token", token).apply {
    description.extras = PersistableBundle().apply { putBoolean("android.content.extra.IS_SENSITIVE", true) }
}

@Composable
private fun EditTokenDialog(
    providerLabel: String,
    currentToken: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var text by remember(currentToken) { mutableStateOf(currentToken) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("Edit token - $providerLabel")
        },
        text = {
            DevOutlinedTextField(
                modifier = Modifier.fillMaxWidth(),
                value = text,
                placeholder = "Paste token",
                onValueChange = { text = it },
                onClear = { text = "" },
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(text) }) { Text("Confirm") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

@Composable
private fun DeleteTokenDialog(
    providerLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("Delete token?")
        },
        text = {
            Text("This will remove the access token for \"$providerLabel\" and break the current session.")
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    text = "Delete",
                    color = AppTheme.colors.error,
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

@Preview(showBackground = true)
@Composable
private fun SessionDetailModuleEmptyPreview() {
    DevTheme {
        SessionDetailModule(sessionManager = SessionManager(emptyList()))
    }
}

@Preview(showBackground = true)
@Composable
private fun SessionDetailModulePreview() {
    val providers = listOf(
        object : SessionProvider {
            override val label = "Auth Token"
            override val token = flowOf("eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0")
            override val onSetToken: (suspend (String?) -> Unit)? = {}
            override val onRefresh: (suspend () -> Unit)? = {}
            override val onLogout: (suspend () -> Unit)? = {}
        },
        object : SessionProvider {
            override val label = "User Session"
            override val token = flowOf<String?>(null)
            override val onLogin: (suspend () -> Unit)? = {}
        },
    )
    DevTheme {
        SessionDetailModule(
            sessionManager = SessionManager(providers),
        )
    }
}
