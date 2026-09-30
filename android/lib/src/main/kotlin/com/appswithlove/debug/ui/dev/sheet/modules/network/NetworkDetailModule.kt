package com.appswithlove.debug.ui.dev.sheet.modules.network

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.DevSectionTitle
import com.appswithlove.debug.ui.component.DevSwitch
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.dev.network.CapturedBody
import com.appswithlove.debug.ui.dev.network.NetworkEntry
import com.appswithlove.debug.ui.dev.network.displayText
import com.appswithlove.debug.ui.dev.network.isoTimestamp
import com.appswithlove.debug.ui.dev.network.statusText
import com.appswithlove.debug.ui.dev.network.toCurl

@Composable
internal fun NetworkDetailModule(
    entry: NetworkEntry,
    onCopy: (String) -> Unit,
    onShare: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var raw by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = modifier.verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ActionButton("Copy URL") { onCopy(entry.url) }
            ActionButton("Copy cURL") { onCopy(entry.toCurl()) }
            ActionButton("Copy response") { onCopy(entry.responseBody?.text ?: "(no body)") }
            DevOutlinedButton(
                text = "Share",
                leadingIcon = { ButtonIcon(TablerIcons.Share) },
                contentColor = MaterialTheme.colorScheme.onSurface,
                onClick = onShare,
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                modifier = Modifier.weight(1f),
                text = redactedCountText(entry.redactedCount),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
            Row(
                modifier = Modifier
                    .heightIn(min = 48.dp)
                    .toggleable(value = raw, role = Role.Switch, onValueChange = { raw = it }),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text = "Raw", color = MaterialTheme.colorScheme.onSurface)
                DevSwitch(
                    modifier = Modifier.padding(start = 8.dp),
                    checked = raw,
                    onCheckedChange = null,
                )
            }
        }

        SelectionContainer {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Section("Overview") {
                    KeyValue("URL", entry.url)
                    KeyValue("Method", entry.method)
                    KeyValue("Status", listOfNotNull(entry.statusText, entry.reason).joinToString(" "), statusColor(entry))
                    KeyValue("Start", isoTimestamp(entry.startedAtMillis))
                    KeyValue("Duration", "${entry.durationMs} ms" + if (entry.isSlow) " (slow)" else "")
                    KeyValue("Request size", entry.requestBytes?.let { "$it bytes" } ?: "–")
                    KeyValue("Response size", entry.responseBytes?.let { "$it bytes" } ?: "–")
                    entry.error?.let { KeyValue("Error", it) }
                }
                Section("Request Headers") { Headers(entry.requestHeaders) }
                Section("Request Body") { Body(entry.requestBody, raw) }
                Section("Response Headers") { Headers(entry.responseHeaders) }
                Section("Response Body") { Body(entry.responseBody, raw) }
            }
        }
        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun ActionButton(text: String, onClick: () -> Unit) {
    DevOutlinedButton(
        text = text,
        leadingIcon = { ButtonIcon(TablerIcons.Copy) },
        contentColor = MaterialTheme.colorScheme.onSurface,
        onClick = onClick,
    )
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        DevSectionTitle(text = title)
        HorizontalDivider()
        content()
    }
}

@Composable
private fun KeyValue(key: String, value: String, valueColor: Color? = null) {
    Row {
        Text(
            modifier = Modifier.width(112.dp),
            text = key,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Text(
            modifier = Modifier.weight(1f),
            text = value,
            style = MaterialTheme.typography.bodySmall,
            color = valueColor ?: MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun Headers(headers: List<Pair<String, String>>) {
    if (headers.isEmpty()) {
        MonospaceText("(no headers)")
        return
    }
    headers.forEach { (name, value) -> MonospaceText("$name: $value") }
}

@Composable
private fun Body(body: CapturedBody?, raw: Boolean) {
    if (body == null) {
        MonospaceText("(no body)")
        return
    }
    MonospaceText(body.displayText(raw))
    if (body.truncated) {
        Text(
            text = "(truncated, ${body.originalBytes ?: "?"} bytes total)",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

@Composable
private fun MonospaceText(text: String) {
    Text(
        modifier = Modifier.fillMaxWidth(),
        text = text,
        style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
        color = MaterialTheme.colorScheme.onSurface,
    )
}

internal fun redactedCountText(count: Int): String = when (count) {
    0 -> ""
    1 -> "1 value redacted"
    else -> "$count values redacted"
}
