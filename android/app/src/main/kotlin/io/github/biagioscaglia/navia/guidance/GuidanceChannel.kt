package io.github.biagioscaglia.navia.guidance

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The `navia/guidance` channel: starts, updates and stops
 * [GuidanceService], asks for the notification permission, and ducks
 * other audio while the voice speaks.
 */
class GuidanceChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, NAME)
    private val ducker = AudioDucker(activity.applicationContext)
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
        GuidanceService.onStopRequested = {
            activity.runOnUiThread { channel.invokeMethod("stopRequested", null) }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: ""
        val text = call.argument<String>("text") ?: ""
        when (call.method) {
            "start" -> result.success(start(title, text))
            "update" -> {
                if (GuidanceService.running) {
                    GuidanceNotification.update(activity, title, text)
                }
                result.success(null)
            }
            "stop" -> {
                activity.stopService(Intent(activity, GuidanceService::class.java))
                result.success(null)
            }
            "notificationsAllowed" ->
                result.success(NotificationManagerCompat.from(activity).areNotificationsEnabled())
            "requestNotifications" -> requestNotifications(result)
            "duck" -> result.success(ducker.duck())
            "unduck" -> {
                ducker.release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Starts the service in the foreground; false when location is not
     * granted, since Android refuses a location service without it.
     */
    private fun start(title: String, text: String): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
        val coarse = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
        if (fine != PackageManager.PERMISSION_GRANTED &&
            coarse != PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val intent = Intent(activity, GuidanceService::class.java)
            .setAction(GuidanceService.ACTION_START)
            .putExtra(GuidanceService.EXTRA_TITLE, title)
            .putExtra(GuidanceService.EXTRA_TEXT, text)
        return try {
            ContextCompat.startForegroundService(activity, intent)
            true
        } catch (_: RuntimeException) {
            // Started from the background, which Android forbids.
            false
        }
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(NotificationManagerCompat.from(activity).areNotificationsEnabled())
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
    }

    /** Called by the activity; true when the request was ours. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_NOTIFICATIONS) return false
        pendingPermission?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        pendingPermission = null
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        GuidanceService.onStopRequested = null
        ducker.release()
    }

    companion object {
        const val NAME = "navia/guidance"
        private const val REQUEST_NOTIFICATIONS = 4101
    }
}
