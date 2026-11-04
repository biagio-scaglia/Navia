package io.github.biagioscaglia.navia.guidance

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service of type "location" that runs only during turn-by-turn
 * guidance. While it runs, Android keeps delivering the location that the
 * app already receives "while in use", with the screen locked or another
 * app open: Navia never needs the background location permission.
 *
 * It holds no location logic itself: positions keep flowing to the Flutter
 * side, which computes the guidance and updates the notification.
 */
class GuidanceService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_REQUEST) {
            // The "Termina" button: Flutter ends guidance, then stops us.
            onStopRequested?.invoke()
            end()
            return START_NOT_STICKY
        }
        val notification = GuidanceNotification.build(
            this,
            intent?.getStringExtra(EXTRA_TITLE) ?: "Navia",
            intent?.getStringExtra(EXTRA_TEXT) ?: "",
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    GuidanceNotification.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(GuidanceNotification.NOTIFICATION_ID, notification)
            }
            running = true
        } catch (_: RuntimeException) {
            // Location access was revoked: guidance stays in the app only.
            end()
        }
        // Not restarted by the system: a guidance session without the app
        // that computes it would be meaningless.
        return START_NOT_STICKY
    }

    /** Swiping Navia away from the recent apps ends guidance too. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        end()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun end() {
        running = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    companion object {
        const val ACTION_START = "io.github.biagioscaglia.navia.guidance.START"
        const val ACTION_STOP_REQUEST =
            "io.github.biagioscaglia.navia.guidance.STOP_REQUEST"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        /** Whether the service is in the foreground now. */
        @Volatile
        var running = false
            private set

        /** Set by [GuidanceChannel] to tell Flutter about "Termina". */
        @Volatile
        var onStopRequested: (() -> Unit)? = null
    }
}
