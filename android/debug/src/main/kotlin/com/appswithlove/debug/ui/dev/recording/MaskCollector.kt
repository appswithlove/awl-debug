package com.appswithlove.debug.ui.dev.recording

import android.graphics.Rect
import android.text.InputType
import android.text.method.PasswordTransformationMethod
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.compose.ui.node.RootForTest
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getAllSemanticsNodes
import androidx.compose.ui.semantics.getOrNull
import kotlin.math.roundToInt

/**
 * Areas of [root]'s window to black out in a recorded frame: password fields and everything marked
 * with `awlDebugMasked`, in window pixels. Runs on the main thread right before the frame is copied.
 */
internal fun collectMaskRects(root: View): List<Rect> = mutableListOf<Rect>().also { collect(root, it) }

private fun collect(view: View, out: MutableList<Rect>) {
    if (view.visibility != View.VISIBLE) return
    if (view.awlDebugMasked || (view is TextView && view.isPasswordField())) {
        out += view.windowRect()
        return
    }
    if (view is RootForTest) collectCompose(view, out)
    if (view is ViewGroup) {
        for (index in 0 until view.childCount) collect(view.getChildAt(index), out)
    }
}

private fun collectCompose(root: RootForTest, out: MutableList<Rect>) {
    root.semanticsOwner.getAllSemanticsNodes(mergingEnabled = false).forEach { node ->
        val config = node.config
        if (SemanticsProperties.Password in config || AwlDebugMaskedKey in config) {
            val bounds = node.boundsInWindow
            out += Rect(
                bounds.left.roundToInt(),
                bounds.top.roundToInt(),
                bounds.right.roundToInt(),
                bounds.bottom.roundToInt(),
            )
        }
    }
}

internal fun TextView.isPasswordField(): Boolean {
    if (transformationMethod is PasswordTransformationMethod) return true
    val variation = inputType and InputType.TYPE_MASK_VARIATION
    return when (inputType and InputType.TYPE_MASK_CLASS) {
        InputType.TYPE_CLASS_TEXT -> variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
        InputType.TYPE_CLASS_NUMBER -> variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
        else -> false
    }
}

private fun View.windowRect(): Rect {
    val location = IntArray(2)
    getLocationInWindow(location)
    return Rect(location[0], location[1], location[0] + width, location[1] + height)
}

/**
 * A value that changes when the text of an editable field in [root]'s window changes, so the recorder notices
 * typing, which happens in the keyboard's own window. Password fields only add their length. Main thread only.
 */
internal fun editableTextFingerprint(root: View): Int {
    var fingerprint = 1
    fun add(value: Int) {
        fingerprint = 31 * fingerprint + value
    }
    fun visit(view: View) {
        if (view.visibility != View.VISIBLE) return
        if (view is TextView && view.onCheckIsTextEditor()) {
            add(if (view.isPasswordField()) view.length() else view.text.toString().hashCode())
        }
        if (view is RootForTest) {
            view.semanticsOwner.getAllSemanticsNodes(mergingEnabled = false).forEach { node ->
                val text = node.config.getOrNull(SemanticsProperties.EditableText) ?: return@forEach
                add(if (SemanticsProperties.Password in node.config) text.length else text.text.hashCode())
            }
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) visit(view.getChildAt(index))
        }
    }
    visit(root)
    return fingerprint
}
