package com.appswithlove.debug.api.extension

import com.appswithlove.debug.api.DevTrigger
import kotlinx.coroutines.flow.StateFlow

/**
 * A group of rows on the panel's start page, below App Info. The panel draws the rows in its own style and
 * separates sections with a divider. Callbacks run on the main thread.
 *
 * @param id Identifies the section; registering another section with the same id replaces this one.
 * @param items Rows in display order. The panel follows every change; an empty list hides the section.
 * @param order Position among the sections, lowest first. Sections with the same order keep their registration order.
 * @param claimedTriggers Gestures the extension handles itself. While the section is registered, these no longer
 * open the panel, and the panel logs a warning when they are among its own triggers.
 */
class DevExtensionSection(
    val id: String,
    val items: StateFlow<List<DevExtensionItem>>,
    val order: Int = 0,
    val claimedTriggers: Set<DevTrigger> = emptySet(),
)

/** One row of a [DevExtensionSection]. */
sealed interface DevExtensionItem {
    /** Bold text, with an optional text button at the end. */
    class Title(val text: String, val action: DevExtensionAction? = null) : DevExtensionItem

    /** Text in [style]. With [copyValue], a tap copies that value to the clipboard. */
    class Text(
        val text: String,
        val style: DevTextStyle = DevTextStyle.Secondary,
        val copyValue: String? = null,
    ) : DevExtensionItem

    /** A labelled switch; the whole row toggles it. */
    class Switch(val text: String, val checked: Boolean, val onCheckedChange: (Boolean) -> Unit) : DevExtensionItem

    /**
     * A row that leads elsewhere, with a chevron and an optional [badge] below the text, such as a count.
     * The panel closes before [onClick] runs.
     */
    class Link(val text: String, val badge: String? = null, val onClick: () -> Unit) : DevExtensionItem
}

/** Text button at the end of a [DevExtensionItem.Title]. */
class DevExtensionAction(val text: String, val enabled: Boolean = true, val onClick: () -> Unit)

/** Look of a [DevExtensionItem.Text]. */
enum class DevTextStyle {
    /** Regular text color. */
    Primary,

    /** Secondary text color, for details. */
    Secondary,

    /** Error color, for problems. */
    Error,

    /** Small monospaced text in the secondary color, for IDs and codes. */
    Monospace,
}
