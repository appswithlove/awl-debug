package com.appswithlove.debug.ui.dev.sheet.modules.performance

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.appswithlove.debug.ui.component.DevOutlinedButton
import com.appswithlove.debug.ui.component.icons.TablerIcons
import com.appswithlove.debug.ui.theme.AppTheme
import com.appswithlove.debug.ui.theme.DevTheme
import com.patrykandpatrick.vico.compose.cartesian.AutoScrollCondition
import com.patrykandpatrick.vico.compose.cartesian.CartesianChartHost
import com.patrykandpatrick.vico.compose.cartesian.Scroll
import com.patrykandpatrick.vico.compose.cartesian.axis.HorizontalAxis
import com.patrykandpatrick.vico.compose.cartesian.axis.VerticalAxis
import com.patrykandpatrick.vico.compose.cartesian.data.CartesianChartModelProducer
import com.patrykandpatrick.vico.compose.cartesian.data.CartesianValueFormatter
import com.patrykandpatrick.vico.compose.cartesian.data.lineSeries
import com.patrykandpatrick.vico.compose.cartesian.layer.rememberLineCartesianLayer
import com.patrykandpatrick.vico.compose.cartesian.rememberCartesianChart
import com.patrykandpatrick.vico.compose.cartesian.rememberVicoScrollState

private const val SAMPLE_INTERVAL_SECONDS = 2

@Composable
fun PerformanceModule(
    modifier: Modifier = Modifier,
    performanceMonitor: PerformanceMonitor,
) {
    val isTracking = performanceMonitor.isTracking.collectAsState()
    val samples = performanceMonitor.samples.collectAsState()
    val latestSample = samples.value.lastOrNull()
    val startBatteryPercent = performanceMonitor.startBatteryPercent.collectAsState()
    val cpuModelProducer = remember { CartesianChartModelProducer() }
    val ramModelProducer = remember { CartesianChartModelProducer() }

    LaunchedEffect(samples.value) {
        val s = samples.value
        if (s.isNotEmpty()) {
            cpuModelProducer.runTransaction { lineSeries { series(s.map { it.cpuPercent }) } }
            ramModelProducer.runTransaction { lineSeries { series(s.map { it.usedRamMb }) } }
        }
    }

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        AnimatedVisibility(visible = isTracking.value && samples.value.isEmpty()) {
            Text(
                text = "Collecting data...",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }

        AnimatedVisibility(visible = isTracking.value && latestSample != null) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (latestSample != null) {
                    MetricBar(
                        label = "CPU",
                        progress = latestSample.cpuPercent / 100f,
                        value = "${latestSample.cpuPercent.toInt()}%",
                    )
                    MetricBar(
                        label = "RAM",
                        progress = latestSample.ramPercent,
                        value = "${latestSample.usedRamMb} MB / ${latestSample.totalRamMb} MB",
                    )
                    val start = startBatteryPercent.value
                    val drop = if (start != null) start - latestSample.batteryPercent else 0
                    MetricBar(
                        label = "Battery draw",
                        progress = latestSample.currentDrawMa / 3000f,
                        value = "${latestSample.currentDrawMa} mA" + if (start != null) "  (${if (drop >= 0) "-" else "+"}${
                            kotlin.math.abs(drop)
                        }% since start)" else "",
                    )
                }
            }
        }

        AnimatedVisibility(visible = isTracking.value && samples.value.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                MetricChart(label = "CPU over time", modelProducer = cpuModelProducer, yAxisSuffix = "%")
                MetricChart(label = "RAM over time", modelProducer = ramModelProducer, yAxisSuffix = " MB")
            }
        }

        AnimatedVisibility(visible = isTracking.value && samples.value.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                horizontalArrangement = Arrangement.End,
            ) {
                DevOutlinedButton(
                    text = "Reset",
                    leadingIcon = {
                        Icon(
                            imageVector = TablerIcons.Refresh,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    },
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    onClick = { performanceMonitor.clear() },
                )
            }
        }
    }
}

@Composable
private fun MetricBar(
    label: String,
    progress: Float,
    value: String,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            )
        }
        LinearProgressIndicator(
            progress = { progress.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth(),
            color = MaterialTheme.colorScheme.onSurface,
            trackColor = AppTheme.colors.iconSubtle,
        )
    }
}

@Composable
private fun MetricChart(
    label: String,
    modelProducer: CartesianChartModelProducer,
    yAxisSuffix: String,
    modifier: Modifier = Modifier,
) {
    val scrollState = rememberVicoScrollState(
        initialScroll = Scroll.Absolute.End,
        autoScroll = Scroll.Absolute.End,
        autoScrollCondition = AutoScrollCondition.OnModelGrowth,
    )
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.Bold,
        )
        CartesianChartHost(
            chart = rememberCartesianChart(
                rememberLineCartesianLayer(),
                startAxis = VerticalAxis.rememberStart(
                    valueFormatter = CartesianValueFormatter { _, value, _ ->
                        "${value.toInt()}$yAxisSuffix"
                    },
                ),
                bottomAxis = HorizontalAxis.rememberBottom(
                    valueFormatter = CartesianValueFormatter { _, value, _ ->
                        formatElapsedSeconds(value.toInt() * SAMPLE_INTERVAL_SECONDS)
                    },
                ),
            ),
            modelProducer = modelProducer,
            scrollState = scrollState,
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp),
        )
    }
}

private fun formatElapsedSeconds(totalSeconds: Int): String {
    if (totalSeconds < 60) return "${totalSeconds}s"
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return if (seconds == 0) "${minutes}m" else "${minutes}m${seconds}s"
}

@Preview(showBackground = true)
@Composable
private fun PerformanceModulePreview() {
    val context = LocalContext.current
    DevTheme {
        PerformanceModule(
            modifier = Modifier.padding(8.dp),
            performanceMonitor = PerformanceMonitor(context),
        )
    }
}
