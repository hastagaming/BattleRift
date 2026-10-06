package com.hastagaming.battlerift.notify

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class BattleRiftNotify(godot: Godot) : GodotPlugin(godot) {

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var requestCounter = 0

    override fun getPluginName(): String = PLUGIN_NAME

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo(SIGNAL_PERMISSION_RESULT, String::class.java),
        SignalInfo(SIGNAL_UPDATE_RESULT, String::class.java, String::class.java, String::class.java)
    )

    override fun onMainDestroy() {
        executor.shutdownNow()
    }

    @UsedByGodot
    fun needsPermission(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

    @UsedByGodot
    fun hasPermission(): Boolean {
        val context = activity?.applicationContext ?: return false
        return NotificationHelper.canNotify(context)
    }

    // Result arrives through the "permission_result" signal:
    // "granted", "denied", "blocked" or "unavailable".
    @UsedByGodot
    fun requestPermission() {
        runOnUiThread {
            val host = activity
            if (host == null) {
                emitSignal(SIGNAL_PERMISSION_RESULT, "unavailable")
                return@runOnUiThread
            }
            if (NotificationHelper.canNotify(host.applicationContext)) {
                emitSignal(SIGNAL_PERMISSION_RESULT, "granted")
                return@runOnUiThread
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                // Notifications were switched off in the system settings.
                emitSignal(SIGNAL_PERMISSION_RESULT, "blocked")
                return@runOnUiThread
            }
            val componentActivity = host as? ComponentActivity
            if (componentActivity == null) {
                emitSignal(SIGNAL_PERMISSION_RESULT, "unavailable")
                return@runOnUiThread
            }
            val key = "battlerift_notify_permission_${requestCounter++}"
            var launcher: ActivityResultLauncher<String>? = null
            launcher = componentActivity.activityResultRegistry.register(
                key,
                ActivityResultContracts.RequestPermission()
            ) { granted ->
                launcher?.unregister()
                val status = when {
                    granted -> "granted"
                    ActivityCompat.shouldShowRequestPermissionRationale(
                        host,
                        Manifest.permission.POST_NOTIFICATIONS
                    ) -> "denied"
                    else -> "blocked"
                }
                emitSignal(SIGNAL_PERMISSION_RESULT, status)
            }
            launcher?.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    @UsedByGodot
    fun openNotificationSettings() {
        runOnUiThread {
            val host = activity ?: return@runOnUiThread
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, host.packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${host.packageName}"))
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                host.startActivity(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Could not open the notification settings", e)
            }
        }
    }

    @UsedByGodot
    fun showNotification(title: String, body: String): Boolean {
        val context = activity?.applicationContext ?: return false
        return NotificationHelper.show(
            context,
            NotificationHelper.ID_GENERAL,
            title,
            body,
            NotificationHelper.openAppIntent(context)
        )
    }

    @UsedByGodot
    fun getInstalledVersion(): String {
        val context = activity?.applicationContext ?: return ""
        return UpdateChecker.installedVersion(context)
    }

    @UsedByGodot
    fun scheduleUpdateChecks(url: String, intervalMinutes: Int): Boolean {
        if (!isValidUpdateUrl(url)) {
            return false
        }
        val context = activity?.applicationContext ?: return false
        val minutes = intervalMinutes.toLong().coerceIn(MIN_INTERVAL_MINUTES, MAX_INTERVAL_MINUTES)
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<UpdateCheckWorker>(minutes, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .setInputData(workDataOf(UpdateCheckWorker.KEY_URL to url))
            .build()
        return try {
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(UNIQUE_PERIODIC, ExistingPeriodicWorkPolicy.UPDATE, request)
            true
        } catch (e: IllegalStateException) {
            Log.w(TAG, "WorkManager is not available", e)
            false
        }
    }

    @UsedByGodot
    fun cancelUpdateChecks() {
        val context = activity?.applicationContext ?: return
        try {
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_PERIODIC)
        } catch (e: IllegalStateException) {
            Log.w(TAG, "WorkManager is not available", e)
        }
    }

    // Result arrives through the "update_check_result" signal:
    // (status, latest_tag, release_url) where status is "newer", "current" or "error".
    @UsedByGodot
    fun checkForUpdateNow(url: String): Boolean {
        if (!isValidUpdateUrl(url)) {
            return false
        }
        val context = activity?.applicationContext ?: return false
        val installed = UpdateChecker.installedVersion(context)
        try {
            executor.execute {
                var status = "error"
                var tag = ""
                var releaseUrl = ""
                try {
                    val outcome = UpdateChecker.evaluate(UpdateChecker.download(url), installed)
                    status = when (outcome.status) {
                        UpdateChecker.Status.NEWER -> "newer"
                        UpdateChecker.Status.CURRENT -> "current"
                        UpdateChecker.Status.ERROR -> "error"
                    }
                    tag = outcome.release?.tag ?: ""
                    releaseUrl = outcome.release?.url ?: ""
                } catch (e: Exception) {
                    Log.w(TAG, "Update check failed", e)
                }
                runOnUiThread { emitSignal(SIGNAL_UPDATE_RESULT, status, tag, releaseUrl) }
            }
        } catch (e: java.util.concurrent.RejectedExecutionException) {
            return false
        }
        return true
    }

    private fun isValidUpdateUrl(url: String): Boolean {
        return url.startsWith("https://") && url.length <= MAX_URL_LENGTH
    }

    companion object {
        private const val TAG = "BattleRiftNotify"
        private const val PLUGIN_NAME = "BattleRiftNotify"
        private const val SIGNAL_PERMISSION_RESULT = "permission_result"
        private const val SIGNAL_UPDATE_RESULT = "update_check_result"
        private const val UNIQUE_PERIODIC = "battlerift_update_checks"
        private const val MIN_INTERVAL_MINUTES = 15L
        private const val MAX_INTERVAL_MINUTES = 10080L
        private const val MAX_URL_LENGTH = 512
    }
}