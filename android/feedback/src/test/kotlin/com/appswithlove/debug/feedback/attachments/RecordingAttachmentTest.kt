package com.appswithlove.debug.feedback.attachments

import com.appswithlove.debug.api.bridge.AwlDebugInternalApi
import com.appswithlove.debug.api.bridge.RecordingExport
import io.kotest.matchers.shouldBe
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(AwlDebugInternalApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RecordingAttachmentTest {

    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun sendsVideoFramesAndTimelineParts() = runTest {
        val export = RecordingExport(
            video = folder.newFile("recording.mp4").apply { writeText("mp4") },
            frames = folder.newFile("frames.jpg").apply { writeText("jpg") },
            timeline = folder.newFile("timeline.md").apply { writeText("md") },
        )

        val attachment = captureRecordingAttachment(source = { export })!!

        attachment.isVideoTooLarge shouldBe false
        attachment.parts.map { listOf(it.name, it.fileName, it.mimeType, it.bytes.decodeToString()) } shouldBe listOf(
            listOf("video", "recording.mp4", "video/mp4", "mp4"),
            listOf("frames", "frames.jpg", "image/jpeg", "jpg"),
            listOf("timeline", "timeline.md", "text/markdown; charset=utf-8", "md"),
        )
    }

    @Test
    fun videoTooLarge_sendsNoRecordingParts() = runTest {
        val attachment = captureRecordingAttachment(source = { RecordingExport(video = null, frames = null, timeline = null) })!!

        attachment.isVideoTooLarge shouldBe true
        attachment.parts shouldBe emptyList()
    }

    @Test
    fun nothingWithoutDebugPanelOrOnFailure() = runTest {
        captureRecordingAttachment(source = null) shouldBe null
        captureRecordingAttachment(source = { null }) shouldBe null
        captureRecordingAttachment(source = { error("encoder failed") }) shouldBe null
        hasRecordingToAttach(source = null) shouldBe false
        hasRecordingToAttach(source = { true }) shouldBe true
    }
}
