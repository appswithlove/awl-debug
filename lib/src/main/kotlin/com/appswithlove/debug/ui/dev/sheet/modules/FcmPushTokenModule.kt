package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.InfoTooltip
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun FcmPushTokenModule(
    token: String?,
    onLongPress: (String) -> Unit,
    onRefresh: (() -> Unit)? = null,
    onRevoke: (() -> Unit)? = null,
) {
    val noTokenText = "N/A"
    val tooltipState = rememberTooltipState()
    val tooltipText = "Long press to copy token"

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "FCM Push Token",
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontWeight = FontWeight(800),
                ),
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.weight(1f))
            InfoTooltip(
                tooltipText = tooltipText,
                tooltipState = tooltipState,
            )
        }
        Text(
            modifier = Modifier.pointerInput(Unit) {
                detectTapGestures(
                    onLongPress = {
                        if (token != null && token != noTokenText) {
                            onLongPress(token)
                        }
                    },
                )
            },
            text = token ?: noTokenText,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface,
        )
        if (onRefresh != null || onRevoke != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (onRefresh != null) {
                    DevOutlinedButton(
                        modifier = Modifier.weight(1f),
                        text = "Refresh",
                        contentColor = MaterialTheme.colorScheme.onSurface,
                        leadingIcon = {
                            Icon(
                                modifier = Modifier.size(18.dp),
                                imageVector = TablerIcons.Refresh,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurface,
                            )
                        },
                        onClick = onRefresh,
                    )
                }
                if (onRevoke != null) {
                    DevOutlinedButton(
                        modifier = Modifier.weight(1f),
                        text = "Revoke",
                        contentColor = AppTheme.colors.error,
                        leadingIcon = {
                            Icon(
                                modifier = Modifier.size(18.dp),
                                imageVector = TablerIcons.Trash,
                                contentDescription = null,
                                tint = AppTheme.colors.error,
                            )
                        },
                        onClick = onRevoke,
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun FcmPushTokenModulePreview() {
    DevTheme {
        FcmPushTokenModule(
            token = "123asdgfa34fv3w4234tc3123asdgfa34fv3w4234tc3123asdgfa34fv3w4234tc3123asdgfa34fv3w4234tc3123asdgfa34fv3w4234tc3",
            onLongPress = {},
        )
    }
}
