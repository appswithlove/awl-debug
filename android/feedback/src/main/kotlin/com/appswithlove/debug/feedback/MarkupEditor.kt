package com.appswithlove.debug.feedback

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.IconToggleButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.toSize
import kotlin.math.hypot

private val MIN_TOUCH_TARGET = 48.dp
private val TOOLBAR_SPACING = 4.dp

/** Height of the one-column toolbar: 10 buttons, 11 gaps and two dividers with their padding. */
private val SINGLE_COLUMN_HEIGHT = MIN_TOUCH_TARGET * 10 + TOOLBAR_SPACING * 11 + 18.dp
private val SWATCH_SIZE = 28.dp
private const val MIN_DRAG_LENGTH_PX = 24f
private const val DISABLED_ALPHA = 0.38f

/** Marks, tool and color of the markup screen; the mark in progress is shown live but only committed on release. */
@Stable
internal class MarkupState {
    val marks = mutableStateListOf<Mark>()
    var tool by mutableStateOf(MarkupTool.Pen)
    var color by mutableStateOf(MarkupColor.Red)
    var inProgress: Mark? by mutableStateOf(null)
        private set

    fun begin(point: Offset) {
        inProgress = when (tool) {
            MarkupTool.Pen -> Mark.Stroke(listOf(point), color)
            MarkupTool.Arrow -> Mark.Arrow(point, point, color)
            MarkupTool.Redact -> Mark.Redact(point, point)
        }
    }

    fun extend(point: Offset) {
        inProgress = when (val mark = inProgress) {
            is Mark.Stroke -> mark.copy(points = mark.points + point)
            is Mark.Arrow -> mark.copy(end = point)
            is Mark.Redact -> mark.copy(end = point)
            null -> null
        }
    }

    /**
     * Commits the mark; an arrow or redact rectangle whose diagonal is shorter than [MIN_DRAG_LENGTH_PX]
     * on a [width] x [height] canvas is dropped as a slip.
     */
    fun end(width: Float, height: Float) {
        val mark = inProgress ?: return
        inProgress = null
        val drag = when (mark) {
            is Mark.Arrow -> mark.start to mark.end
            is Mark.Redact -> mark.start to mark.end
            is Mark.Stroke -> null
        }
        if (drag != null && hypot((drag.second.x - drag.first.x) * width, (drag.second.y - drag.first.y) * height) < MIN_DRAG_LENGTH_PX) return
        marks.add(mark)
    }

    fun cancel() {
        inProgress = null
    }

    fun undo() {
        marks.removeLastOrNull()
    }
}

/**
 * Screenshot with the markup canvas and, right beside it, the vertical toolbar.
 * A touch for which [isDismissingKeyboard] is true only closes the keyboard and leaves no mark.
 */
@Composable
internal fun MarkupEditor(
    screenshot: ImageBitmap,
    state: MarkupState,
    enabled: Boolean,
    modifier: Modifier = Modifier,
    isDismissingKeyboard: () -> Boolean = { false },
) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MarkupCanvas(
            screenshot = screenshot,
            state = state,
            enabled = enabled,
            isDismissingKeyboard = isDismissingKeyboard,
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
        )
        MarkupToolbar(
            state = state,
            enabled = enabled,
            modifier = Modifier.fillMaxHeight(),
        )
    }
}

/** One finger draws; two fingers zoom and pan. Marks stay in image coordinates, so zoom never moves them. */
@Composable
private fun MarkupCanvas(
    screenshot: ImageBitmap,
    state: MarkupState,
    enabled: Boolean,
    isDismissingKeyboard: () -> Boolean,
    modifier: Modifier = Modifier,
) {
    val ratio = screenshot.width.toFloat() / screenshot.height.toFloat()
    val canvasDescription = stringResource(R.string.feedback_markup_canvas)
    var viewport by remember { mutableStateOf(Viewport()) }
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .aspectRatio(ratio, matchHeightConstraintsFirst = true)
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant)
                .clipToBounds()
                .semantics { contentDescription = canvasDescription }
                .pointerInput(enabled) {
                    if (!enabled) return@pointerInput
                    fun normalized(position: Offset): Offset {
                        val frame = size.toSize()
                        val point = viewport.toContent(position, frame)
                        return Offset((point.x / frame.width).coerceIn(0f, 1f), (point.y / frame.height).coerceIn(0f, 1f))
                    }
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        if (isDismissingKeyboard()) return@awaitEachGesture
                        state.begin(normalized(down.position))
                        down.consume()
                        var zooming = false
                        while (true) {
                            val event = awaitPointerEvent()
                            val pressed = event.changes.count { it.pressed }
                            if (pressed == 0) break
                            if (pressed > 1 && !zooming) {
                                zooming = true
                                state.cancel()
                            }
                            if (zooming) {
                                viewport = viewport.transformed(event.calculateCentroid(), event.calculatePan(), event.calculateZoom(), size.toSize())
                            } else {
                                event.changes.firstOrNull { it.id == down.id && it.pressed }?.let { state.extend(normalized(it.position)) }
                            }
                            event.changes.forEach { it.consume() }
                        }
                        if (!zooming) state.end(size.width.toFloat(), size.height.toFloat())
                    }
                },
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        transformOrigin = TransformOrigin(0f, 0f)
                        scaleX = viewport.scale
                        scaleY = viewport.scale
                        val translation = viewport.translation(size)
                        translationX = translation.x
                        translationY = translation.y
                    },
            ) {
                Image(
                    bitmap = screenshot,
                    contentDescription = null,
                    contentScale = ContentScale.FillBounds,
                    modifier = Modifier.fillMaxSize(),
                )
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val style = Stroke(width = STROKE_WIDTH_FRACTION * size.width, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    (state.marks + listOfNotNull(state.inProgress)).forEach { mark ->
                        if (mark is Mark.Redact) {
                            val area = mark.rect(size.width, size.height)
                            drawRect(color = Color(mark.color.argb), topLeft = area.topLeft, size = area.size)
                            return@forEach
                        }
                        mark.polylines(size.width, size.height).filter { it.isNotEmpty() }.forEach { line ->
                            val path = Path().apply {
                                moveTo(line.first().x, line.first().y)
                                line.drop(1).forEach { lineTo(it.x, it.y) }
                                if (line.size == 1) lineTo(line.first().x + 0.1f, line.first().y)
                            }
                            drawPath(path, color = Color(mark.color.argb), style = style)
                        }
                    }
                }
            }
        }
    }
}

/**
 * Tools, colors and undo/clear in one column; in two columns when one would not fit the height, for example on
 * small screens or with a large font size, where the text fields leave less room.
 */
@Composable
private fun MarkupToolbar(
    state: MarkupState,
    enabled: Boolean,
    modifier: Modifier = Modifier,
) {
    @Composable
    fun Tools() = MarkupTool.entries.forEach { tool ->
        ToolToggle(tool = tool, selected = state.tool == tool, enabled = enabled, onSelect = { state.tool = tool })
    }

    @Composable
    fun Colors() = Column(modifier = Modifier.selectableGroup(), verticalArrangement = Arrangement.spacedBy(TOOLBAR_SPACING)) {
        MarkupColor.entries.forEach { color ->
            // Redact is always black; the colors apply to Pen and Arrow only.
            ColorSwatch(
                color = color,
                selected = state.color == color,
                enabled = enabled && state.tool != MarkupTool.Redact,
                onSelect = { state.color = color },
            )
        }
    }

    @Composable
    fun History() {
        IconButton(onClick = state::undo, enabled = enabled && state.marks.isNotEmpty(), modifier = Modifier.size(MIN_TOUCH_TARGET)) {
            Icon(painter = painterResource(R.drawable.feedback_ic_undo), contentDescription = stringResource(R.string.feedback_undo))
        }
        IconButton(onClick = state.marks::clear, enabled = enabled && state.marks.isNotEmpty(), modifier = Modifier.size(MIN_TOUCH_TARGET)) {
            Icon(painter = painterResource(R.drawable.feedback_ic_delete), contentDescription = stringResource(R.string.feedback_clear))
        }
    }

    @Composable
    fun ToolbarColumn(content: @Composable () -> Unit) = Column(
        modifier = Modifier
            .fillMaxHeight()
            .width(MIN_TOUCH_TARGET)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(TOOLBAR_SPACING, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) { content() }

    BoxWithConstraints(modifier = modifier) {
        if (maxHeight >= SINGLE_COLUMN_HEIGHT) {
            ToolbarColumn {
                Tools()
                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                Colors()
                HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                History()
            }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(TOOLBAR_SPACING)) {
                ToolbarColumn {
                    Tools()
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                    History()
                }
                ToolbarColumn { Colors() }
            }
        }
    }
}

@Composable
private fun ToolToggle(
    tool: MarkupTool,
    selected: Boolean,
    enabled: Boolean,
    onSelect: () -> Unit,
) {
    val (icon, label) = when (tool) {
        MarkupTool.Pen -> R.drawable.feedback_ic_edit to R.string.feedback_tool_pen
        MarkupTool.Arrow -> R.drawable.feedback_ic_arrow to R.string.feedback_tool_arrow
        MarkupTool.Redact -> R.drawable.feedback_ic_redact to R.string.feedback_tool_redact
    }
    IconToggleButton(
        checked = selected,
        onCheckedChange = { onSelect() },
        enabled = enabled,
        colors = IconButtonDefaults.iconToggleButtonColors(
            checkedContainerColor = MaterialTheme.colorScheme.primaryContainer,
            checkedContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        ),
        modifier = Modifier.size(MIN_TOUCH_TARGET),
    ) {
        Icon(painter = painterResource(icon), contentDescription = stringResource(label))
    }
}

@Composable
private fun ColorSwatch(
    color: MarkupColor,
    selected: Boolean,
    enabled: Boolean,
    onSelect: () -> Unit,
) {
    val label = stringResource(color.label)
    Box(
        modifier = Modifier
            .size(MIN_TOUCH_TARGET)
            .clip(CircleShape)
            .selectable(selected = selected, enabled = enabled, role = Role.RadioButton, onClick = onSelect)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(SWATCH_SIZE + 8.dp)
                .alpha(if (enabled) 1f else DISABLED_ALPHA)
                .border(
                    width = 3.dp,
                    color = if (selected) MaterialTheme.colorScheme.primary else Color.Transparent,
                    shape = CircleShape,
                )
                .padding(4.dp)
                .background(Color(color.argb), CircleShape)
                // Keeps swatches close to the surface color (black on dark, yellow on light) visible.
                .border(1.dp, MaterialTheme.colorScheme.outline, CircleShape),
        )
    }
}
