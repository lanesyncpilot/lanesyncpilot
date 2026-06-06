package com.lanesync.dashcam

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

data class DashcamClip(
  val id: String,
  val preserved: Boolean,
  val files: List<String>,
  val sizeBytes: Long,
  val playbackFile: String?,
  val dongleId: String,
  val recordedAt: String = "",
  val location: String = "",
  val durationSec: Int = 0,
  val thumbnailHue: Float = 160f,
) {
  fun playbackUrl(baseUrl: String, token: String = ""): String? {
    val file = playbackFile ?: return null
    val encodedId = URLEncoder.encode(id, StandardCharsets.UTF_8.toString()).replace("+", "%20")
    val encodedFile = URLEncoder.encode(file, StandardCharsets.UTF_8.toString()).replace("+", "%20")
    val base = "${baseUrl.trimEnd('/')}/video/$encodedId/$encodedFile"
    return if (token.isBlank()) base else "$base?token=${URLEncoder.encode(token, StandardCharsets.UTF_8.toString())}"
  }

  fun formattedSize(): String {
    val mb = sizeBytes / (1024.0 * 1024.0)
    return if (mb < 1024) String.format("%.1f MB", mb) else String.format("%.2f GB", mb / 1024.0)
  }

  fun displayTitle(): String = id.replace("--", " · seg ")

  fun formattedDuration(): String {
    if (durationSec <= 0) return ""
    val m = durationSec / 60
    val s = durationSec % 60
    return if (m > 0) "${m}m ${s}s" else "${s}s"
  }
}

object MockDashcamData {
  fun clips(dongleId: String) = listOf(
    DashcamClip(
      id = "2024-06-05--14",
      preserved = true,
      files = listOf("fcamera.hevc", "qcamera.ts", "dcamera.hevc"),
      sizeBytes = 248_000_000,
      playbackFile = "fcamera.hevc",
      dongleId = dongleId,
      recordedAt = "Today · 2:34 PM",
      location = "I-280 S · San Francisco",
      durationSec = 62,
      thumbnailHue = 155f,
    ),
    DashcamClip(
      id = "2024-06-04--31",
      preserved = true,
      files = listOf("fcamera.hevc", "qcamera.ts"),
      sizeBytes = 312_000_000,
      playbackFile = "fcamera.hevc",
      dongleId = dongleId,
      recordedAt = "Yesterday · 6:12 PM",
      location = "US-101 N · Palo Alto",
      durationSec = 84,
      thumbnailHue = 185f,
    ),
    DashcamClip(
      id = "2024-06-03--08",
      preserved = true,
      files = listOf("fcamera.hevc"),
      sizeBytes = 196_000_000,
      playbackFile = "fcamera.hevc",
      dongleId = dongleId,
      recordedAt = "Jun 3 · 9:41 AM",
      location = "CA-85 · Mountain View",
      durationSec = 45,
      thumbnailHue = 130f,
    ),
    DashcamClip(
      id = "2024-06-01--22",
      preserved = true,
      files = listOf("fcamera.hevc", "ecamera.hevc"),
      sizeBytes = 421_000_000,
      playbackFile = "fcamera.hevc",
      dongleId = dongleId,
      recordedAt = "Jun 1 · 11:05 PM",
      location = "I-880 S · Oakland",
      durationSec = 118,
      thumbnailHue = 210f,
    ),
  )
}

class DashcamApi(
  private val client: OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(8, TimeUnit.SECONDS)
    .readTimeout(120, TimeUnit.SECONDS)
    .build(),
) {
  suspend fun health(baseUrl: String, token: String? = null): Boolean = withContext(Dispatchers.IO) {
    val req = request(baseUrl.trimEnd('/') + "/health", token)
    client.newCall(req).execute().use { it.isSuccessful && it.body?.string()?.contains("\"ok\":true") == true }
  }

  suspend fun listClips(baseUrl: String, token: String? = null): List<DashcamClip> = withContext(Dispatchers.IO) {
    val req = request(baseUrl.trimEnd('/') + "/clips", token)
    client.newCall(req).execute().use { resp ->
      if (!resp.isSuccessful) throw IllegalStateException("HTTP ${resp.code}")
      val body = resp.body?.string() ?: throw IllegalStateException("empty response")
      parseClips(JSONObject(body))
    }
  }

  suspend fun downloadClip(
    baseUrl: String,
    clip: DashcamClip,
    destDir: File,
    token: String? = null,
    onProgress: (Float) -> Unit = {},
  ): File = withContext(Dispatchers.IO) {
    val url = clip.playbackUrl(baseUrl, token.orEmpty()) ?: throw IllegalStateException("No playback file")
    val out = File(destDir, "${clip.id.replace('/', '_')}_${clip.playbackFile}")
    val req = request(url, token)
    client.newCall(req).execute().use { resp ->
      if (!resp.isSuccessful) throw IllegalStateException("Download failed: HTTP ${resp.code}")
      val body = resp.body ?: throw IllegalStateException("empty body")
      val total = body.contentLength().coerceAtLeast(1L)
      body.byteStream().use { input ->
        FileOutputStream(out).use { output ->
          val buffer = ByteArray(64 * 1024)
          var readTotal = 0L
          while (true) {
            val n = input.read(buffer)
            if (n <= 0) break
            output.write(buffer, 0, n)
            readTotal += n
            onProgress(readTotal.toFloat() / total.toFloat())
          }
        }
      }
    }
    out
  }

  private fun request(url: String, token: String?): Request {
    val builder = Request.Builder().url(url).get()
    if (!token.isNullOrBlank()) {
      builder.header("Authorization", "Bearer $token")
    }
    return builder.build()
  }

  private fun parseClips(json: JSONObject): List<DashcamClip> {
    val arr: JSONArray = when {
      json.has("clips") -> json.getJSONArray("clips")
      json.has("routes") -> json.getJSONArray("routes")
      else -> JSONArray()
    }
    return buildList {
      for (i in 0 until arr.length()) {
        val o = arr.optJSONObject(i) ?: continue
        val filesArr = o.optJSONArray("files") ?: JSONArray()
        val files = buildList {
          for (j in 0 until filesArr.length()) {
            filesArr.optString(j).takeIf { it.isNotBlank() }?.let { add(it) }
          }
        }
        add(
          DashcamClip(
            id = o.optString("id"),
            preserved = o.optBoolean("preserved", true),
            files = files,
            sizeBytes = o.optLong("size_bytes", 0),
            playbackFile = o.optString("playback_file").takeIf { it.isNotBlank() },
            dongleId = o.optString("dongle_id", ""),
          )
        )
      }
    }.filter { it.id.isNotBlank() }
  }
}
