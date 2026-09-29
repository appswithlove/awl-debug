package com.appswithlove.debug.ui.dev.sheet.modules.deeplinks

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import androidx.core.net.toUri

/** Extra on the launch intent of a delayed deeplink notification when the app uses its own handler. */
internal const val DEEPLINK_EXTRA = "AWLDebugDeeplinkURL"

/**
 * Fires deeplinks with the app's handler from `DevModulesConfig.deeplinkHandler`, or with an
 * `ACTION_VIEW` intent limited to the app's package. A deeplink that arrives before `DevSheet` set the
 * handler (cold start from a notification) waits until it is set.
 */
internal object DeeplinkDispatcher {
    private var handler: ((String) -> Unit)? = null
    private var pendingUrl: String? = null

    fun setHandler(value: ((String) -> Unit)?) {
        handler = value
        if (value == null) return
        pendingUrl?.let { url ->
            pendingUrl = null
            value(url)
        }
    }

    /** Returns `false` when no screen of the app handles [url]. */
    fun fire(context: Context, url: String): Boolean {
        handler?.let {
            it(url)
            return true
        }
        return openWithIntent(context, url)
    }

    /** Passes the URL of a tapped notification to the app's handler, waiting for it on a cold start. */
    fun deliverToHandler(url: String) {
        handler?.invoke(url) ?: run { pendingUrl = url }
    }

    fun openWithIntent(context: Context, url: String): Boolean = try {
        context.startActivity(viewIntent(context, url).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    fun viewIntent(context: Context, url: String): Intent =
        Intent(Intent.ACTION_VIEW, url.toUri()).setPackage(context.packageName)
}

/** A deeplink needs a scheme, for example `myapp://home` or `https://example.com/path`. */
internal fun isValidDeeplink(url: String): Boolean {
    val scheme = url.trim().substringBefore("://", missingDelimiterValue = "")
    return scheme.isNotEmpty() && scheme.all { it.isLetterOrDigit() || it in "+-." } && scheme.first().isLetter() &&
        url.trim().length > scheme.length + 3 && url.none { it.isWhitespace() }
}
