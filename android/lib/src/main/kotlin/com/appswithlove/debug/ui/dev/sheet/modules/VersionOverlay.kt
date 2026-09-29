package com.appswithlove.debug.ui.dev.sheet.modules

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.appswithlove.debug.api.DevConfig

/**
 * `AWL <version> (<build>)` in the top start corner below the status bar. It has no pointer input,
 * so touches reach the app underneath, and it shows up in screenshots of the app content.
 */
@Composable
internal fun VersionOverlay(devConfig: DevConfig, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.TopStart) {
        Text(
            modifier = Modifier
                .padding(start = 4.dp, top = 2.dp)
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.6f), RoundedCornerShape(3.dp))
                .padding(horizontal = 3.dp, vertical = 1.dp),
            text = versionOverlayText(devConfig),
            fontSize = 8.sp,
            lineHeight = 10.sp,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

internal fun versionOverlayText(devConfig: DevConfig): String = "AWL ${devConfig.versionName} (${devConfig.versionCode})"
