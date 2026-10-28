package com.appswithlove.debug.ui.dev.sheet.modules.performance

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.domain.storage.DevStore
import kotlinx.coroutines.launch

private val OVERLAY_WIDTH = 200.dp
private val OVERLAY_HEIGHT = 110.dp
private const val SPARKLINE_SAMPLES = 30

/**
 * Hosts the draggable performance overlay over the app content. Visibility and position are stored
 * per device; while the overlay is visible the [monitor] keeps sampling.
 */
@Composable
internal fun PerformanceOverlayHost(
    monitor: PerformanceMonitor,
    devStore: DevStore,
    onLongPress: () -> Unit,
) {
    val preferences by devStore.performanceOverlay.collectAsState(initial = null)
    val scope = rememberCoroutineScope()
    val saved = preferences ?: return
    var position by remember(saved.xDp, saved.yDp) { mutableStateOf(DpOffset(saved.xDp.dp, saved.yDp.dp)) }

    LaunchedEffect(saved.isVisible) {
        monitor.setOverlayVisible(saved.isVisible)
    }
    if (!saved.isVisible) return

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val maxX = (maxWidth - OVERLAY_WIDTH).coerceAtLeast(0.dp)
        val maxY = (maxHeight - OVERLAY_HEIGHT).coerceAtLeast(0.dp)
        val clamped = DpOffset(position.x.coerceIn(0.dp, maxX), position.y.coerceIn(0.dp, maxY))
        PerformanceOverlay(
            monitor = monitor,
            modifier = Modifier.offset(clamped.x, clamped.y),
            onDrag = { delta ->
                position = DpOffset((clamped.x + delta.x).coerceIn(0.dp, maxX), (clamped.y + delta.y).coerceIn(0.dp, maxY))
            },
            onDragEnd = {
                scope.launch {
                    devStore.setPerformanceOverlayPosition(position.x.value, position.y.value)
                }
            },
            onLongPress = onLongPress,
        )
    }
}

/** Small box with RAM, CPU and UI freeze plus a CPU sparkline. Takes touches only on itself. */
@Composable
internal fun PerformanceOverlay(
    monitor: PerformanceMonitor,
    onDrag: (DpOffset) -> Unit,
    onDragEnd: () -> Unit,
    onLongPress: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val samples by monitor.samples.collectAsState()
    val freezes by monitor.freezes.collectAsState()
    val latest = samples.lastOrNull()
    val density = LocalDensity.current
    val currentOnDrag by rememberUpdatedState(onDrag)
    val currentOnDragEnd by rememberUpdatedState(onDragEnd)
    val currentOnLongPress by rememberUpdatedState(onLongPress)

    Column(
        modifier = modifier
            .size(OVERLAY_WIDTH, OVERLAY_HEIGHT)
            .background(Color(0xCC000000), RoundedCornerShape(12.dp))
            .pointerInput(Unit) {
                detectDragGestures(onDragEnd = { currentOnDragEnd() }) { change, dragAmount ->
                    change.consume()
                    with(density) { currentOnDrag(DpOffset(dragAmount.x.toDp(), dragAmount.y.toDp())) }
                }
            }
            .pointerInput(Unit) {
                detectTapGestures(onLongPress = { currentOnLongPress() })
            }
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        OverlayLine("RAM", latest?.let { "${it.usedRamMb} MB" })
        OverlayLine("CPU", latest?.let { "${it.cpuPercent.toInt()}%" })
        OverlayLine(
            "UI freeze",
            latest?.let { "${it.uiFreezeMs} ms" + if (freezes.count > 0) " · ${freezes.count}×" else "" },
        )
        Sparkline(
            values = samples.takeLast(SPARKLINE_SAMPLES).map { it.cpuPercent / 100f },
            height = 28.dp,
        )
    }
}

@Composable
private fun OverlayLine(label: String, value: String?) {
    Text(
        text = "$label  ${value ?: "–"}",
        style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
        color = Color.White,
    )
}

@Composable
private fun Sparkline(values: List<Float>, height: Dp) {
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(height)
            .padding(top = 4.dp),
    ) {
        if (values.size < 2) return@Canvas
        val step = size.width / (SPARKLINE_SAMPLES - 1)
        val path = Path()
        values.forEachIndexed { index, value ->
            val point = Offset(index * step, size.height * (1f - value.coerceIn(0f, 1f)))
            if (index == 0) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y)
        }
        drawPath(path, color = Color(0xFF4CAF50), style = Stroke(width = 2.dp.toPx()))
    }
}
