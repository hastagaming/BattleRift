package com.hastagaming.battlerift.notify

import android.content.Context
import android.content.pm.PackageManager
import org.json.JSONException
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

object UpdateChecker {
    private const val MAX_BYTES = 1_000_000
    private const val TIMEOUT_MS = 15_000

    enum class Status { NEWER, CURRENT, ERROR }

    data class Release(val tag: String, val name: String, val url: String)

    data class Outcome(val status: Status, val release: Release?)

    class HttpStatusException(val code: Int) : IOException("HTTP $code")

    fun parseRelease(json: String): Release? {
        return try {
            val root = JSONObject(json)
            val tag = root.optString("tag_name", "").trim()
            if (tag.isEmpty()) {
                null
            } else {
                Release(tag, root.optString("name", tag), root.optString("html_url", ""))
            }
        } catch (e: JSONException) {
            null
        }
    }

    fun evaluate(json: String, installed: String): Outcome {
        val release = parseRelease(json) ?: return Outcome(Status.ERROR, null)
        if (VersionCompare.parse(installed) == null) {
            return Outcome(Status.ERROR, release)
        }
        val status = if (VersionCompare.isNewer(release.tag, installed)) Status.NEWER else Status.CURRENT
        return Outcome(status, release)
    }

    @Suppress("DEPRECATION")
    fun installedVersion(context: Context): String {
        return try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: ""
        } catch (e: PackageManager.NameNotFoundException) {
            ""
        }
    }

    @Throws(IOException::class)
    fun download(url: String): String {
        require(url.startsWith("https://")) { "The update URL must use https" }
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            connection.setRequestProperty("Accept", "application/vnd.github+json")
            connection.setRequestProperty("User-Agent", "BattleRift-UpdateCheck")
            val code = connection.responseCode
            if (code !in 200..299) {
                throw HttpStatusException(code)
            }
            connection.inputStream.use { stream ->
                val buffer = ByteArrayOutputStream()
                val chunk = ByteArray(8192)
                var total = 0
                while (true) {
                    val read = stream.read(chunk)
                    if (read < 0) {
                        break
                    }
                    total += read
                    if (total > MAX_BYTES) {
                        throw IOException("The response is too large")
                    }
                    buffer.write(chunk, 0, read)
                }
                return buffer.toString(Charsets.UTF_8.name())
            }
        } finally {
            connection.disconnect()
        }
    }
}