package com.appswithlove.debug.feedback

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/** No-op stub: release builds render [content] only, without screenshot recording or shake detection. */
@Suppress("UNUSED_PARAMETER")
@Composable
fun FeedbackHost(config: FeedbackConfig?, content: @Composable () -> Unit) {
    content()
}

/** No-op stub: release builds show no feedback entry. */
@Suppress("UNUSED_PARAMETER")
@Composable
fun FeedbackLauncher(modifier: Modifier = Modifier) = Unit
