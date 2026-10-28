package com.appswithlove.debug.ui.dev.recording

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** A frame of a recording: capture time and whether it was taken in landscape. */
internal data class TimelineFrame(val timeMillis: Long, val isLandscape: Boolean)

/** A touch start or end from `events.tsv`, coordinates 0–1. */
internal data class TimelineTouch(val timeMillis: Long, val began: Boolean, val x: Float, val y: Float)

/** A pause without frames longer than this shows up as a `gap` row. */
private const val GAP_THRESHOLD_MS = 1_000L

/**
 * Builds `timeline.md`: one row per frame, touch, orientation change and pause (right after the frame before
 * it). A touch belongs to the latest frame taken at or before it (the first frame for earlier touches). Touches
 * outside the frames' time range are left out.
 */
internal fun recordingTimeline(
    frames: List<TimelineFrame>,
    touches: List<TimelineTouch>,
    fps: Int,
    timeZone: TimeZone = TimeZone.getDefault(),
): String {
    val start = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply { this.timeZone = timeZone }
    val time = SimpleDateFormat("HH:mm:ss.SSS", Locale.US).apply { this.timeZone = timeZone }
    val builder = StringBuilder()
        .append("# Recording timeline\n")
        .append("start: ")
        .append(frames.firstOrNull()?.let { start.format(Date(it.timeMillis)) } ?: "-")
        .append(" · frames: ").append(frames.size)
        .append(" · fps: ").append(fps).append("\n\n")
        .append("| time | frame | event |\n")
        .append("|---|---|---|\n")
    if (frames.isEmpty()) return builder.toString()

    fun row(timeMillis: Long, frame: Int, event: String) {
        builder.append("| ").append(time.format(Date(timeMillis))).append(" | ").append(frame).append(" | ")
            .append(event).append(" |\n")
    }

    val lastFrameTime = frames.last().timeMillis
    val pending = touches
        .filter { it.timeMillis <= lastFrameTime && it.timeMillis >= frames.first().timeMillis - GAP_THRESHOLD_MS }
        .sortedBy { it.timeMillis }
        .toMutableList()
    frames.forEachIndexed { index, frame ->
        val number = index + 1
        val previous = frames.getOrNull(index - 1)
        if (previous != null && previous.isLandscape != frame.isLandscape) {
            row(frame.timeMillis, number, if (frame.isLandscape) "orientation landscape" else "orientation portrait")
        }
        row(frame.timeMillis, number, "frame")
        val nextFrameTime = frames.getOrNull(index + 1)?.timeMillis ?: Long.MAX_VALUE
        if (nextFrameTime != Long.MAX_VALUE && nextFrameTime - frame.timeMillis > GAP_THRESHOLD_MS) {
            row(frame.timeMillis, number, String.format(Locale.US, "gap %.1fs", (nextFrameTime - frame.timeMillis) / 1000.0))
        }
        while (pending.isNotEmpty() && pending.first().timeMillis < nextFrameTime) {
            val touch = pending.removeAt(0)
            val event = String.format(
                Locale.US,
                "touch %s x=%.2f y=%.2f",
                if (touch.began) "began" else "ended",
                touch.x,
                touch.y,
            )
            row(touch.timeMillis, number, event)
        }
    }
    return builder.toString()
}

/** Parses `events.tsv` lines (`<time ms>\t<began|ended>\t<x>\t<y>`), skipping broken ones. */
internal fun parseTouchEvents(lines: List<String>): List<TimelineTouch> = lines.mapNotNull { line ->
    val parts = line.split('\t')
    if (parts.size != 4) return@mapNotNull null
    val time = parts[0].toLongOrNull() ?: return@mapNotNull null
    val began = when (parts[1]) {
        "began" -> true
        "ended" -> false
        else -> return@mapNotNull null
    }
    val x = parts[2].toFloatOrNull() ?: return@mapNotNull null
    val y = parts[3].toFloatOrNull() ?: return@mapNotNull null
    TimelineTouch(time, began, x, y)
}
