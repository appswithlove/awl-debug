package com.appswithlove.debug.ui.dev.sheet.modules.deeplinks

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import com.appswithlove.debug.api.DeeplinkItem
import com.appswithlove.debug.ui.component.DevOutlinedTextField
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun DeeplinksModule(
    modifier: Modifier = Modifier,
    deeplinks: List<DeeplinkItem> = emptyList(),
) {
    val context = LocalContext.current
    var deeplinkText by remember { mutableStateOf("") }
    var deeplinkError by remember { mutableStateOf<String?>(null) }

    fun shootDeeplink(url: String) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
            deeplinkError = null
        } catch (_: Exception) {
            deeplinkError = "Invalid deeplink"
        }
    }

    Column(
        modifier = modifier
            .padding(vertical = 12.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top,
        ) {
            DevOutlinedTextField(
                modifier = Modifier.weight(1f),
                value = deeplinkText,
                placeholder = "Enter deeplink",
                onValueChange = {
                    deeplinkText = it
                    deeplinkError = null
                },
                onClear = {
                    deeplinkText = ""
                    deeplinkError = null
                },
                isError = deeplinkError != null,
                errorText = deeplinkError,
            )
            Box(
                modifier = Modifier.height(56.dp),
                contentAlignment = Alignment.Center,
            ) {
                OutlinedIconButton(
                    modifier = Modifier.size(48.dp),
                    onClick = { shootDeeplink(deeplinkText) },
                    enabled = deeplinkText.isNotBlank() && deeplinkError == null,
                ) {
                    Text(text = "🚀", fontSize = 20.sp)
                }
            }
        }

        if (deeplinks.isNotEmpty()) {
            Text(
                text = "Predefined",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            deeplinks.forEach { item ->
                DeeplinkRow(
                    item = item,
                    onClick = { shootDeeplink(item.url) },
                )
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun DeeplinkRow(
    item: DeeplinkItem,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            text = item.label,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurface,
        )
        Text(
            text = item.url,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun DeeplinksModulePreview() {
    DevTheme {
        DeeplinksModule(
            deeplinks = listOf(
                DeeplinkItem(
                    label = "Home",
                    url = "myapp://home",
                ),
                DeeplinkItem(
                    label = "Profile",
                    url = "myapp://profile/123",
                ),
            ),
        )
    }
}
