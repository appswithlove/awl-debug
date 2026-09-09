package com.appswithlove.debug.ui.dev.sheet.modules.session

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.R
import com.appswithlove.debug.api.session.SessionProvider
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme
import kotlinx.coroutines.flow.flowOf

@Composable
fun SessionModule(
    states: List<SessionManager.ProviderState>,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = "Session",
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight(800)),
                color = MaterialTheme.colorScheme.onSurface,
            )
            states.forEach { state ->
                ProviderStatusRow(state)
            }
        }
        Icon(
            painter = painterResource(R.drawable.ic_chevron_right),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
        )
    }
}

@Composable
internal fun ProviderStatusRow(state: SessionManager.ProviderState) {
    val isLoggedIn = state.token != null
    val positiveColor = AppTheme.colors.positive
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Canvas(modifier = Modifier.size(8.dp)) {
            drawCircle(
                color = if (isLoggedIn) {
                    positiveColor
                } else {
                    Color.Gray.copy(alpha = 0.5f)
                }
            )
        }
        Text(
            text = state.provider.label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun SessionModulePreview() {
    DevTheme {
        SessionModule(
            states = listOf(
                SessionManager.ProviderState(
                    provider = object : SessionProvider {
                        override val label = "Auth Token"
                        override val token = flowOf("eyJhbGci")
                    },
                    token = "eyJhbGci",
                ),
                SessionManager.ProviderState(
                    provider = object : SessionProvider {
                        override val label = "Refresh Token"
                        override val token = flowOf<String?>(null)
                    },
                    token = null,
                ),
            ),
            onClick = {},
        )
    }
}
