package com.appswithlove.debug.example

import android.content.Context
import android.widget.Toast
import com.appswithlove.debug.api.extension.AwlDebugExtensions
import com.appswithlove.debug.api.extension.DevExtensionItem
import com.appswithlove.debug.api.extension.DevExtensionSection
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Adds a section below App Info, the way a library extends the panel. With `debug-no-op` the same calls compile,
 * and nothing is shown.
 */
object DemoExtension {
    private val items = MutableStateFlow<List<DevExtensionItem>>(emptyList())

    fun register(context: Context): AutoCloseable {
        show(context.applicationContext, isOn = true)
        return AwlDebugExtensions.register(DevExtensionSection(id = "demo", items = items))
    }

    private fun show(context: Context, isOn: Boolean) {
        items.value = listOf(
            DevExtensionItem.Title("Demo extension: ${if (isOn) "On" else "Off"}"),
            DevExtensionItem.Switch("Enabled", checked = isOn) { show(context, isOn = it) },
            DevExtensionItem.Link("Show a toast") {
                Toast.makeText(context, "Hello from the demo extension", Toast.LENGTH_SHORT).show()
            },
        )
    }
}
