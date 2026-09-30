package com.appswithlove.debug

import android.content.Intent
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DEEPLINK_EXTRA
import com.appswithlove.debug.ui.dev.sheet.modules.deeplinks.DeeplinkDispatcher

object AwlDebug {
    /**
     * Call from the launcher activity's `onCreate` and `onNewIntent` when the app sets
     * `DevModulesConfig.deeplinkHandler`: a tapped delayed-deeplink notification then reaches that handler.
     *
     * @return `true` when [intent] came from such a notification.
     */
    fun handleDeeplinkIntent(intent: Intent): Boolean {
        val url = intent.getStringExtra(DEEPLINK_EXTRA) ?: return false
        intent.removeExtra(DEEPLINK_EXTRA)
        DeeplinkDispatcher.deliverToHandler(url)
        return true
    }
}
