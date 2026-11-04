package io.github.biagioscaglia.navia.guidance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.github.biagioscaglia.navia.MainActivity
import io.github.biagioscaglia.navia.R

/**
 * The ongoing notification shown during turn-by-turn guidance: the next
 * maneuver, what is left of the route, and a button that ends guidance.
 */
object GuidanceNotification {
    const val CHANNEL_ID = "guidance"
    const val NOTIFICATION_ID = 1001

    /** Silent: the voice guidance already speaks, the notification only shows. */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Navigazione",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Prossima manovra mentre la guida è attiva."
                setShowBadge(false)
            },
        )
    }

    fun build(context: Context, title: String, text: String): Notification {
        ensureChannel(context)
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            context,
            1,
            Intent(context, GuidanceService::class.java)
                .setAction(GuidanceService.ACTION_STOP_REQUEST),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_guidance)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .addAction(0, "Termina", stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(
                NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE,
            )
            .build()
    }

    /** Replaces the text of the notification of a running service. */
    fun update(context: Context, title: String, text: String) {
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        try {
            manager.notify(NOTIFICATION_ID, build(context, title, text))
        } catch (_: SecurityException) {
            // Notifications were turned off meanwhile: guidance goes on.
        }
    }
}
