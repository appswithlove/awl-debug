package com.appswithlove.debug.ui.component

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/** Writes [text] to `cacheDir/awl-debug/[fileName]` and opens the share sheet for it. */
internal suspend fun shareTextFile(context: Context, fileName: String, text: String, chooserTitle: String) {
    val file = withContext(Dispatchers.IO) {
        val exportDir = File(context.cacheDir, "awl-debug").apply { mkdirs() }
        File(exportDir, fileName).apply { writeText(text, Charsets.UTF_8) }
    }
    shareFile(context, file, "text/plain", chooserTitle)
}

/** Opens the share sheet for [file], which must be inside `cacheDir/awl-debug`. */
internal suspend fun shareFile(context: Context, file: File, mimeType: String, chooserTitle: String) {
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.awldebug.fileprovider", file)
    val shareIntent = Intent(Intent.ACTION_SEND).apply {
        type = mimeType
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    withContext(Dispatchers.Main) {
        context.startActivity(Intent.createChooser(shareIntent, chooserTitle))
    }
}
