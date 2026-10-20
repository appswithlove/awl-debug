package com.appswithlove.debug.ui.component

import androidx.core.content.FileProvider

/**
 * Library-owned [FileProvider], so its manifest entry never clashes with a `FileProvider` the
 * host app declares. Only exposes files below `cacheDir/awl-debug/`.
 */
internal class AwlDebugFileProvider : FileProvider()
