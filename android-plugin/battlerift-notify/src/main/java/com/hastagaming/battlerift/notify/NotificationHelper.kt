package com.hastagaming.battlerift.notify

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {
    const val CHANNEL_ID = "br_updates"
    const val ID_UPDATE = 4301
    const val ID_GENERAL = 4302

    fun canNotify(context: Context): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    fun openAppIntent(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        launch.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        )
        return PendingIntent.getActivity(context, 0, launch, pendingFlags())
    }

    fun openUrlIntent(context: Context, url: String): PendingIntent? {
        if (!url.startsWith("https://")) {
            return null
        }
        val view = Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(context, 1, view, pendingFlags())
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(CHANNEL_ID, "Game updates", NotificationManager.IMPORTANCE_DEFAULT)
        channel.description = "Tells you when a new BattleRift version is available"
        manager.createNotificationChannel(channel)
    }

    @SuppressLint("MissingPermission")
    fun show(context: Context, id: Int, title: String, body: String, target: PendingIntent?): Boolean {
        if (!canNotify(context)) {
            return false
        }
        ensureChannel(context)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.br_ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
        if (target != null) {
            builder.setContentIntent(target)
        }
        return try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
            true
        } catch (e: SecurityException) {
            false
        }
    }
}