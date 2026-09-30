package com.appswithlove.debug.ui.component

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Buttons side by side with equal widths, or stacked at full width when a label would not fit on one line,
 * for example with a large font size.
 */
@Composable
internal fun DevButtonRow(
    modifier: Modifier = Modifier,
    spacing: Dp = 8.dp,
    content: @Composable () -> Unit,
) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        if (measurables.isEmpty()) return@Layout layout(0, 0) {}
        val spacingPx = spacing.roundToPx()
        // Without a width limit (e.g. in a horizontal scroll) the buttons sit side by side, as wide as the widest one.
        val width = if (constraints.hasBoundedWidth) {
            constraints.maxWidth
        } else {
            measurables.size * measurables.maxOf { it.maxIntrinsicWidth(Constraints.Infinity) } + spacingPx * (measurables.size - 1)
        }
        val itemWidth = (width - spacingPx * (measurables.size - 1)) / measurables.size
        val fitsSideBySide = measurables.all { it.maxIntrinsicWidth(Constraints.Infinity) <= itemWidth }
        if (fitsSideBySide) {
            val itemHeight = measurables.maxOf { it.maxIntrinsicHeight(itemWidth) }
            val placeables = measurables.map { it.measure(Constraints.fixed(itemWidth, itemHeight)) }
            layout(width, itemHeight) {
                placeables.forEachIndexed { index, placeable -> placeable.placeRelative(index * (itemWidth + spacingPx), 0) }
            }
        } else {
            val placeables = measurables.map { it.measure(Constraints(minWidth = width, maxWidth = width)) }
            layout(width, placeables.sumOf { it.height } + spacingPx * (placeables.size - 1)) {
                var y = 0
                placeables.forEach { placeable ->
                    placeable.placeRelative(0, y)
                    y += placeable.height + spacingPx
                }
            }
        }
    }
}
