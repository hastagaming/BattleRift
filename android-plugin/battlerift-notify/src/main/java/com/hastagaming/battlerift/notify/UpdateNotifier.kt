package com.hastagaming.battlerift.notify

import android.content.Context

object UpdateNotifier {
    private const val PREFS = "battlerift_notify"
    private const val KEY_LAST = "last_notified_version"

    // Shows the update notification once per version. If notifications are not
    // allowed yet, nothing is remembered, so a later check can still notify.
    fun notifyOnce(context: Context, release: UpdateChecker.Release): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getString(KEY_LAST, null) == release.tag) {
            return false
        }
        val target = NotificationHelper.openUrlIntent(context, release.url)
            ?: NotificationHelper.openAppIntent(context)
        val shown = NotificationHelper.show(
            context,
            NotificationHelper.ID_UPDATE,
            "BattleRift update available",
            "Version ${release.tag} is ready. Tap to download.",
            target
        )
        if (shown) {
            prefs.edit().putString(KEY_LAST, release.tag).apply()
        }
        return shown
    }
}