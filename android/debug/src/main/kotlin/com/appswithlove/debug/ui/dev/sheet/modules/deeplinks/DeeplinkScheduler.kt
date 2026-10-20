package com.appswithlove.debug.ui.dev.sheet.modules.deeplinks

import android.Manifest
import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.appswithlove.debug.api.DeeplinkItem

private const val CHANNEL_ID = "awl_debug"
private const val EXTRA_URL = "url"
private const val EXTRA_TITLE = "title"
private const val EXTRA_USES_HANDLER = "usesHandler"

internal sealed interface ScheduleResult {
    data object Scheduled : ScheduleResult
    data object MissingPermission : ScheduleResult
    data object Failed : ScheduleResult
}

/**
 * Posts a local notification after a delay; tapping it opens the deeplink, also on a cold start.
 * The SDK never asks for the notification permission itself.
 */
internal object DeeplinkScheduler {

    fun canNotify(context: Context): Boolean {
        val permissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return permissionGranted && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun schedule(context: Context, item: DeeplinkItem, delaySeconds: Int, usesHandler: Boolean): ScheduleResult {
        if (!canNotify(context)) return ScheduleResult.MissingPermission
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return ScheduleResult.Failed
        val intent = Intent(context, DeeplinkNotificationReceiver::class.java)
            .putExtra(EXTRA_URL, item.url)
            .putExtra(EXTRA_TITLE, item.label)
            .putExtra(EXTRA_USES_HANDLER, usesHandler)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            item.url.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val triggerAt = SystemClock.elapsedRealtime() + delaySeconds * 1_000L
        return try {
            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            } else {
                // Without the exact alarm permission the system may deliver it a little later.
                alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            }
            ScheduleResult.Scheduled
        } catch (_: SecurityException) {
            ScheduleResult.Failed
        }
    }

    // canNotify checks the permission; a revoke in between is caught below.
    @SuppressLint("MissingPermission")
    fun showNotification(context: Context, url: String, title: String, usesHandler: Boolean) {
        if (!canNotify(context)) return
        val notificationManager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Debug deeplinks", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val viewIntent = DeeplinkDispatcher.viewIntent(context, url)
        // Apps with their own handler get the URL through AwlDebug.handleDeeplinkIntent; others open it directly.
        val contentIntent = if (!usesHandler && viewIntent.resolveActivity(context.packageManager) != null) {
            viewIntent
        } else {
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.putExtra(DEEPLINK_EXTRA, url) ?: return
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val pendingIntent = PendingIntent.getActivity(
            context,
            url.hashCode(),
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentTitle("Deeplink")
            .setContentText(title)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(url.hashCode(), notification)
        } catch (_: SecurityException) {
            // Permission revoked between check and post.
        }
    }
}

internal class DeeplinkNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val url = intent.getStringExtra(EXTRA_URL) ?: return
        DeeplinkScheduler.showNotification(
            context = context,
            url = url,
            title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { url },
            usesHandler = intent.getBooleanExtra(EXTRA_USES_HANDLER, false),
        )
    }
}
