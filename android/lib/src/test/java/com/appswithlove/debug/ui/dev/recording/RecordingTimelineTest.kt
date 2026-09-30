package com.appswithlove.debug.ui.dev.recording

import io.kotest.matchers.shouldBe
import java.util.TimeZone
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RecordingTimelineTest {
    private val zurich = TimeZone.getTimeZone("Europe/Zurich")

    // 2026-09-29T10:14:31.000+02:00
    private val start = 1_790_669_671_000L

    @Test
    fun timeline_listsFramesTouchesGapsAndOrientation() {
        val frames = listOf(
            TimelineFrame(start, isLandscape = false),
            TimelineFrame(start + 333, isLandscape = false),
            TimelineFrame(start + 12_733, isLandscape = true),
        )
        val touches = parseTouchEvents(
            listOf(
                "${start + 120}\tbegan\t0.5200\t0.3100",
                "${start + 300}\tended\t0.5200\t0.3100",
                "broken line",
                "${start + 99_000}\tbegan\t0.1\t0.1",
            ),
        )

        recordingTimeline(frames, touches, fps = 3, timeZone = zurich) shouldBe """
            # Recording timeline
            start: 2026-09-29T10:14:31.000+02:00 · frames: 3 · fps: 3

            | time | frame | event |
            |---|---|---|
            | 10:14:31.000 | 1 | frame |
            | 10:14:31.120 | 1 | touch began x=0.52 y=0.31 |
            | 10:14:31.300 | 1 | touch ended x=0.52 y=0.31 |
            | 10:14:31.333 | 2 | frame |
            | 10:14:31.333 | 2 | gap 12.4s |
            | 10:14:43.733 | 3 | orientation landscape |
            | 10:14:43.733 | 3 | frame |

        """.trimIndent()
    }

    @Test
    fun pickFrames_spreadsEvenlyAndKeepsFirstAndLast() {
        ContactSheet.pickFrames(5) shouldBe listOf(0, 1, 2, 3, 4)
        val picked = ContactSheet.pickFrames(1_800)
        picked.size shouldBe 60
        picked.first() shouldBe 0
        picked.last() shouldBe 1_799
    }
}
