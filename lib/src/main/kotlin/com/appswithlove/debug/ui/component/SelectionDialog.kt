package com.appswithlove.debug.ui.component

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.appswithlove.debug.R
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun SelectionDialog(
    show: MutableState<Boolean>,
    title: String,
    values: List<Int>,
    selectedOption: Int,
    onOptionSelected: (Int) -> Unit,
) {
    if (show.value) {
        Dialog(
            onDismissRequest = { show.value = false },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            Column(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .background(
                        color = AppTheme.colors.background,
                        shape = MaterialTheme.shapes.medium,
                    ),
                horizontalAlignment = Alignment.Start,
            ) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    modifier = Modifier.padding(horizontal = 24.dp),
                    text = title,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(16.dp))
                Options(
                    options = values,
                    selectedOption = selectedOption,
                    onSelect = { onOptionSelected(it) },
                )
            }
        }
    }
}

@Composable
private fun Options(
    options: List<Int>,
    selectedOption: Int,
    onSelect: (Int) -> Unit,
) {
    Column {
        options.forEachIndexed { index, option ->
            Option(
                value = option,
                isSelected = selectedOption == option,
                onClick = { onSelect(option) },
            )
            if (index != options.lastIndex) {
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }
        }
    }
}

@Composable
private fun Option(
    value: Int,
    isSelected: Boolean,
    onClick: (Int) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick(value) },
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                modifier = Modifier.height(24.dp),
                text = value.toString(),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.weight(1f))
            if (isSelected) {
                Icon(
                    modifier = Modifier.size(24.dp),
                    painter = painterResource(id = R.drawable.ic_check),
                    tint = MaterialTheme.colorScheme.onSurface,
                    contentDescription = null,
                )
            }
        }
    }
}

@Preview(
    showBackground = true,
    uiMode = Configuration.UI_MODE_NIGHT_YES,
)
@Composable
private fun SelectionDialogDarkPreview() {
    DevTheme {
        val show = remember { mutableStateOf(true) }
        SelectionDialog(
            show = show,
            title = "Number of logs per session",
            values = listOf(10, 50, 250, 500, 750, 1000),
            selectedOption = 750,
            onOptionSelected = {},
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun SelectionDialogLightPreview() {
    DevTheme {
        val show = remember { mutableStateOf(true) }
        SelectionDialog(
            show = show,
            title = "Number of logs per session",
            values = listOf(10, 50, 250, 500, 750, 1000),
            selectedOption = 750,
            onOptionSelected = {},
        )
    }
}
