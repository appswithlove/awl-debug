package com.appswithlove.debug.ui.dev.recording

import android.view.View
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.semantics
import com.appswithlove.debug.R

internal val AwlDebugMaskedKey = SemanticsPropertyKey<Unit>("AwlDebugMasked") { parent, _ -> parent }

/** Covers this element with a black box in screen recordings. No effect in `debug-no-op`. */
fun Modifier.awlDebugMasked(): Modifier = semantics { this[AwlDebugMaskedKey] = Unit }

/** `true` covers this view and its children with a black box in screen recordings. No effect in `debug-no-op`. */
var View.awlDebugMasked: Boolean
    get() = getTag(R.id.awl_debug_masked) == true
    set(value) = setTag(R.id.awl_debug_masked, value)
