package com.appswithlove.debug.ui.dev.sheet.modules.deeplinks

import android.Manifest
import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ResolveInfo
import androidx.test.core.app.ApplicationProvider
import com.appswithlove.debug.AwlDebug
import com.appswithlove.debug.api.DeeplinkItem
import com.appswithlove.debug.domain.storage.DevStore
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DeeplinksTest {

    private val context: Application = ApplicationProvider.getApplicationContext()
    private val item = DeeplinkItem(label = "Profile", url = "myapp://profile/123")

    @After
    fun tearDown() {
        DeeplinkDispatcher.setHandler(null)
    }

    @Test
    fun isValidDeeplink_requiresScheme() {
        isValidDeeplink("myapp://profile/123") shouldBe true
        isValidDeeplink("https://example.com/a") shouldBe true
        isValidDeeplink("not a url") shouldBe false
        isValidDeeplink("myapp://") shouldBe false
    }

    @Test
    fun fire_withHandler_callsHandlerInsteadOfIntent() {
        val fired = mutableListOf<String>()
        DeeplinkDispatcher.setHandler { fired += it }

        DeeplinkDispatcher.fire(context, item.url) shouldBe true

        fired shouldBe listOf(item.url)
        shadowOf(context).nextStartedActivity shouldBe null
    }

    @Test
    fun handleDeeplinkIntent_coldStart_waitsForHandler() {
        val fired = mutableListOf<String>()
        val intent = Intent().putExtra(DEEPLINK_EXTRA, item.url)

        AwlDebug.handleDeeplinkIntent(intent) shouldBe true
        DeeplinkDispatcher.setHandler { fired += it }

        fired shouldBe listOf(item.url)
        AwlDebug.handleDeeplinkIntent(Intent()) shouldBe false
    }

    @Test
    fun schedule_withoutNotificationPermission_failsWithoutAsking() {
        shadowOf(context).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        shadowOf(context.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)

        DeeplinkScheduler.schedule(context, item, delaySeconds = 5, usesHandler = false) shouldBe
            ScheduleResult.MissingPermission
    }

    @Test
    fun schedule_thenReceiver_postsNotificationThatOpensTheDeeplink() {
        shadowOf(context).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        // The app has a screen for the deeplink.
        shadowOf(context.packageManager).addResolveInfoForIntent(
            DeeplinkDispatcher.viewIntent(context, item.url),
            ResolveInfo().apply { activityInfo = ActivityInfo().apply { packageName = context.packageName; name = "Main" } },
        )

        DeeplinkScheduler.schedule(context, item, delaySeconds = 5, usesHandler = false) shouldBe ScheduleResult.Scheduled

        val alarm = shadowOf(context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).nextScheduledAlarm
        alarm shouldNotBe null
        DeeplinkNotificationReceiver().onReceive(context, shadowOf(alarm!!.operation).savedIntent)
        val notification = shadowOf(context.getSystemService(NotificationManager::class.java)).allNotifications.single()
        shadowOf(notification.contentIntent).savedIntent.dataString shouldBe item.url
    }

    @Test
    fun savedDeeplinks_areStoredInOrder() = runTest {
        val store = DevStore(context)
        val saved = listOf(item, DeeplinkItem(label = "Home", url = "myapp://home"))

        store.setSavedDeeplinks(saved)

        DevStore(context).savedDeeplinks.first() shouldBe saved
    }
}
