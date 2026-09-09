package com.appswithlove.debug.ui.component

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun DevOutlinedTextField(
    modifier: Modifier = Modifier,
    value: String,
    placeholder: String,
    onValueChange: (String) -> Unit,
    onClear: () -> Unit,
    isError: Boolean = false,
    errorText: String? = null,
) {
    Column(modifier = modifier) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = {
                Text(
                    text = placeholder,
                    style = MaterialTheme.typography.bodyLarge,
                )
            },
            trailingIcon = {
                if (value.isNotEmpty()) {
                    IconButton(onClick = onClear) {
                        Icon(
                            imageVector = TablerIcons.X,
                            contentDescription = "Clear",
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            },
            isError = isError,
            singleLine = true,
            shape = MaterialTheme.shapes.small,
            colors = OutlinedTextFieldDefaults.colors().copy(
                focusedTextColor = MaterialTheme.colorScheme.onSurface,
                cursorColor = MaterialTheme.colorScheme.onSurface,
                focusedLabelColor = MaterialTheme.colorScheme.onSurface,
                focusedIndicatorColor = MaterialTheme.colorScheme.onSurface,
                errorIndicatorColor = AppTheme.colors.error,
                textSelectionColors = TextSelectionColors(
                    handleColor = MaterialTheme.colorScheme.onSurface,
                    backgroundColor = AppTheme.colors.iconSubtle,
                ),
            ),
        )
        if (isError && errorText != null) {
            Text(
                text = errorText,
                style = MaterialTheme.typography.bodySmall,
                color = AppTheme.colors.error,
                modifier = Modifier.padding(start = 16.dp, top = 4.dp),
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun DevOutlinedTextFieldPreview() {
    DevTheme {
        Column {
            DevOutlinedTextField(
                modifier = Modifier.fillMaxWidth(),
                value = "",
                placeholder = "Placeholder text",
                onValueChange = {},
                onClear = {},
            )
            Spacer(modifier = Modifier.height(16.dp))
            DevOutlinedTextField(
                modifier = Modifier.fillMaxWidth(),
                value = "Value text",
                placeholder = "Placeholder text",
                onValueChange = {},
                onClear = {},
            )
            Spacer(modifier = Modifier.height(16.dp))
            DevOutlinedTextField(
                modifier = Modifier.fillMaxWidth(),
                value = "myapp://invalid_deeplink",
                placeholder = "Placeholder text",
                isError = true,
                errorText = "Invalid deeplink",
                onValueChange = {},
                onClear = {},
            )
        }
    }
}
