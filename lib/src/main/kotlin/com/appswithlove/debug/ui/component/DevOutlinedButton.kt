package com.appswithlove.debug.ui.component

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.icons.TablerIcons

private const val DISABLED_CONTENT_ALPHA = 0.38f

@Composable
fun DevOutlinedButton(
    modifier: Modifier = Modifier,
    text: String,
    leadingIcon: @Composable (() -> Unit)? = null,
    contentColor: Color = Color.Black,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val disabledContentColor = contentColor.copy(alpha = DISABLED_CONTENT_ALPHA)
    val actualContentColor = if (enabled) contentColor else disabledContentColor

    OutlinedButton(
        modifier = modifier,
        onClick = onClick,
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = Color.Transparent,
            contentColor = contentColor,
            disabledContainerColor = Color.Transparent,
            disabledContentColor = contentColor,
        ),
        shape = MaterialTheme.shapes.small,
        border = BorderStroke((1.6).dp, actualContentColor),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (leadingIcon != null) {
                leadingIcon()
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(
                text = text,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun DevOutlinedButtonRegularPreview() {
    DevOutlinedButton(
        modifier = Modifier.padding(horizontal = 4.dp),
        text = "Clear logs",
        leadingIcon = {
            Icon(
                imageVector = TablerIcons.Eraser,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface,
            )
        },
        contentColor = MaterialTheme.colorScheme.onSurface,
        onClick = {},
    )
}

@Preview(showBackground = true)
@Composable
private fun DevOutlinedButtonNegativePreview() {
    DevOutlinedButton(
        modifier = Modifier.padding(horizontal = 4.dp),
        text = "Simulate crash",
        leadingIcon = {
            Icon(
                imageVector = TablerIcons.AlertTriangle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.error
            )
        },
        contentColor = MaterialTheme.colorScheme.error,
        onClick = {},
    )
}
