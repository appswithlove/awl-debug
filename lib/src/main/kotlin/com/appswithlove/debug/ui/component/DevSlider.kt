package com.appswithlove.debug.ui.component

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderColors
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme

@Composable
fun DevSlider(
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    onValueChange: (Float) -> Unit,
) {
    val sliderColors = SliderColors(
        thumbColor = MaterialTheme.colorScheme.onSurface,
        activeTrackColor = MaterialTheme.colorScheme.onSurface,
        activeTickColor = MaterialTheme.colorScheme.onSurface,
        inactiveTrackColor = AppTheme.colors.iconSubtle,
        inactiveTickColor = AppTheme.colors.background,
        disabledThumbColor = MaterialTheme.colorScheme.onSurface,
        disabledActiveTrackColor = MaterialTheme.colorScheme.onSurface,
        disabledActiveTickColor = MaterialTheme.colorScheme.onSurface,
        disabledInactiveTrackColor = MaterialTheme.colorScheme.onSurface,
        disabledInactiveTickColor = MaterialTheme.colorScheme.onSurface
    )

    Slider(
        value = value,
        onValueChange = onValueChange,
        valueRange = valueRange,
        steps = steps,
        colors = sliderColors,
    )
}

@Preview(showBackground = true)
@Composable
private fun DevSliderPreview() {
    DevTheme {
        DevSlider(
            value = 1f,
            valueRange = 0.5f..2.0f,
            steps = 5,
            onValueChange = {},
        )
    }
}
