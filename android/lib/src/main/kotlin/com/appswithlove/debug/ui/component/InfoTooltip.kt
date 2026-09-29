package com.appswithlove.debug.ui.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipAnchorPosition
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.TooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme
import kotlinx.coroutines.launch

@Composable
fun InfoTooltip(
    tooltipText: String,
    tooltipState: TooltipState,
) {
    val coroutineScope = rememberCoroutineScope()

    TooltipBox(
        positionProvider = TooltipDefaults.rememberTooltipPositionProvider(
            TooltipAnchorPosition.Above,
            spacingBetweenTooltipAndAnchor = 2.dp
        ),
        tooltip = {
            PlainTooltip { Text(tooltipText) }
        },
        state = tooltipState,
    ) {
        Icon(
            modifier = Modifier
                .clip(CircleShape)
                .clickable {
                    coroutineScope.launch {
                        tooltipState.show()
                    }
                },
            imageVector = TablerIcons.InfoCircle,
            contentDescription = "Info",
            tint = AppTheme.colors.iconSubtle,
        )
    }
}
