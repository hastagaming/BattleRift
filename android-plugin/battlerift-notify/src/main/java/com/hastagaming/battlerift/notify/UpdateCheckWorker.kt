package com.hastagaming.battlerift.notify

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException

class UpdateCheckWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val url = inputData.getString(KEY_URL)
        if (url.isNullOrEmpty()) {
            return Result.failure()
        }
        return withContext(Dispatchers.IO) { check(url) }
    }

    private fun check(url: String): Result {
        return try {
            val installed = UpdateChecker.installedVersion(applicationContext)
            val outcome = UpdateChecker.evaluate(UpdateChecker.download(url), installed)
            val release = outcome.release
            if (outcome.status == UpdateChecker.Status.NEWER && release != null) {
                UpdateNotifier.notifyOnce(applicationContext, release)
            }
            Result.success()
        } catch (e: UpdateChecker.HttpStatusException) {
            if (e.code >= 500) Result.retry() else Result.success()
        } catch (e: IOException) {
            Result.retry()
        } catch (e: Exception) {
            Log.w(TAG, "Update check failed", e)
            Result.success()
        }
    }

    companion object {
        const val KEY_URL = "url"
        private const val TAG = "BattleRiftNotify"
    }
}