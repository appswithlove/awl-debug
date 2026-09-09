package com.appswithlove.debug.ui.dev.sheet.modules.session

import android.content.ClipData
import androidx.compose.foundation.background
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
fun SessionDetailModule(
    modifier: Modifier = Modifier,
    sessionManager: SessionManager,
) {
    val states by sessionManager.states.collectAsState()
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboard.current
    val revealedTokens = remember { mutableStateMapOf<String, Boolean>() }

    val editTarget = remember { mutableStateOf<SessionManager.ProviderState?>(null) }
    val deleteTarget = remember { mutableStateOf<SessionManager.ProviderState?>(null) }

    Column(
        modifier = modifier
            .padding(vertical = 12.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        states.forEachIndexed { index, state ->
            ProviderCard(
                state = state,
                isRevealed = revealedTokens[state.provider.label] == true,
                onRevealToggle = {
                    revealedTokens[state.provider.label] =
                        revealedTokens[state.provider.label] != true
                },
                onCopy = {
                    val token = state.token ?: return@ProviderCard
                    scope.launch {
                        clipboard.setClipEntry(
                            ClipEntry(ClipData.newPlainText(token, token))
                        )
                    }
                },
                onEdit = state.provider.onSetToken?.let { { editTarget.value = state } },
                onDelete = state.provider.onSetToken?.let { { deleteTarget.value = state } },
                onLogin = state.provider.onLogin?.let { action ->
                    { scope.launch { action() } }
                },
                onRefresh = state.provider.onRefresh?.let { action ->
                    { scope.launch { action() } }
                },
                onLogout = state.provider.onLogout?.let { action ->
                    { scope.launch { action() } }
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
                scope.launch {
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
                scope.launch {
                    sessionManager.setToken(target.provider, null)
                }
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
    onCopy: () -> Unit,
    onEdit: (() -> Unit)?,
    onDelete: (() -> Unit)?,
    onLogin: (() -> Unit)?,
    onRefresh: (() -> Unit)?,
    onLogout: (() -> Unit)?,
) {
    val isLoggedIn = state.token != null

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

        ProviderStatusRow(state = state)

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
                    text = if (isRevealed) {
                        state.token.take(60).let { if (state.token.length > 60) "$it…" else it }
                    } else {
                        "••••••••••••••••"
                    },
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onRevealToggle) {
                    Icon(
                        imageVector = if (isRevealed) TablerIcons.EyeOff else TablerIcons.Eye,
                        contentDescription = if (isRevealed) "Hide token" else "Reveal token",
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    )
                }
            }
        }

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (isLoggedIn) {
                DevOutlinedButton(
                    text = "Copy",
                    leadingIcon = {
                        Icon(
                            imageVector = TablerIcons.Copy,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    },
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    onClick = onCopy,
                )
            }
            if (onEdit != null) {
                DevOutlinedButton(
                    text = "Edit",
                    leadingIcon = {
                        Icon(
                            imageVector = TablerIcons.Pencil,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    },
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    onClick = onEdit,
                )
            }
            if (isLoggedIn && onDelete != null) {
                DevOutlinedButton(
                    text = "Delete",
                    leadingIcon = {
                        Icon(
                            imageVector = TablerIcons.Trash,
                            contentDescription = null,
                            tint = AppTheme.colors.error,
                        )
                    },
                    contentColor = AppTheme.colors.error,
                    onClick = onDelete,
                )
            }
            if (onLogin != null) {
                DevOutlinedButton(
                    text = "Login",
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    onClick = onLogin,
                )
            }
            if (isLoggedIn && onRefresh != null) {
                DevOutlinedButton(
                    text = "Refresh",
                    leadingIcon = {
                        Icon(
                            imageVector = TablerIcons.Refresh,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    },
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    onClick = onRefresh,
                )
            }
            if (isLoggedIn && onLogout != null) {
                DevOutlinedButton(
                    text = "Logout",
                    contentColor = AppTheme.colors.error,
                    onClick = onLogout,
                )
            }
        }
    }
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
        containerColor = AppTheme.colors.background,
        title = {
            Text(
                text = "Edit token - $providerLabel",
                color = MaterialTheme.colorScheme.onSurface,
            )
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
            TextButton(onClick = { onConfirm(text) }) {
                Text(
                    text = "Confirm",
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(
                    text = "Cancel",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }
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
        containerColor = AppTheme.colors.background,
        title = {
            Text(
                text = "Delete token?",
                color = MaterialTheme.colorScheme.onSurface,
            )
        },
        text = {
            Text(
                text = "This will remove the access token for \"$providerLabel\" and break the current session.",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            )
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
            TextButton(onClick = onDismiss) {
                Text(
                    text = "Cancel",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }
        },
    )
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
