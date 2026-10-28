package com.appswithlove.debug.ui.component

import android.content.Context
import androidx.core.content.FileProvider
import androidx.test.core.app.ApplicationProvider
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.matchers.string.shouldEndWith
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AwlDebugFileProviderTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private val authority = "${context.packageName}.awldebug.fileprovider"

    // FileProvider caches its paths per authority, so both cases share one Robolectric data dir.
    @Test
    fun getUriForFile_onlySharesFilesInLibCacheDir() {
        val exportFile = File(context.cacheDir, "awl-debug/android-logs.txt")

        FileProvider.getUriForFile(context, authority, exportFile).toString() shouldEndWith
            "awl_debug/android-logs.txt"
        shouldThrow<IllegalArgumentException> {
            FileProvider.getUriForFile(context, authority, File(context.filesDir, "app-data.txt"))
        }
    }
}
