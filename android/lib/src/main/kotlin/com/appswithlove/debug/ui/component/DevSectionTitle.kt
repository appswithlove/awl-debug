package com.appswithlove.debug.ui.component

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight

/** Title of a section inside a module page; a heading for TalkBack navigation. */
@Composable
internal fun DevSectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        modifier = modifier.semantics { heading() },
        text = text,
        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
        color = MaterialTheme.colorScheme.onSurface,
    )
}

/** Small label above a group of list rows, e.g. "Predefined" or "System". */
@Composable
internal fun DevGroupLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        modifier = modifier.semantics { heading() },
        text = text,
        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
    )
}
