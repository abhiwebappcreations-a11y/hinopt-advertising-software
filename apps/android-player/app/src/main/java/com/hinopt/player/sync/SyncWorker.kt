package com.hinopt.player.sync

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.hinopt.player.data.db.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class SyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    private val db = AppDatabase.getInstance(appContext)

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            Log.i(TAG, "Starting periodic background signage sync...")

            // 1. Upload pending Proof-of-Play tallies
            uploadPendingProofOfPlay()

            // 2. Poll manifest delta from Advertising Service
            pollManifestDelta()

            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "SyncWorker error: ${e.message}", e)
            Result.retry()
        }
    }

    private suspend fun uploadPendingProofOfPlay() {
        val pending = db.proofOfPlayDao().getPendingUploads()
        if (pending.isEmpty()) return

        Log.i(TAG, "Uploading ${pending.size} proof-of-play impression records to cloud...")
        val sharedPrefs = applicationContext.getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
        val deviceId = sharedPrefs.getString("device_id", null) ?: return
        val backendUrl = sharedPrefs.getString("ads_backend_url", "http://10.0.2.2:8082")

        val url = URL("$backendUrl/v1/displays/$deviceId/playback-reports")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true

        val root = JSONObject().apply {
            put("screen_id", deviceId)
            put("batch_timestamp", System.currentTimeMillis().toString())
            val arr = JSONArray()
            pending.forEach { p ->
                arr.put(JSONObject().apply {
                    put("campaign_id", p.campaign_id)
                    put("asset_id", p.asset_id)
                    put("date", p.play_date)
                    put("completed_impressions", p.completed_impressions)
                    put("total_seconds_played", p.total_seconds_played)
                    put("interrupted_impressions", p.interrupted_impressions)
                })
            }
            put("records", arr)
        }

        conn.outputStream.use { os ->
            os.write(root.toString().toByteArray())
        }

        if (conn.responseCode in 200..299) {
            pending.forEach { p ->
                db.proofOfPlayDao().markUploaded(p.campaign_id, p.asset_id, p.play_date)
            }
            Log.i(TAG, "Successfully uploaded and acknowledged PoP records.")
        }
    }

    private suspend fun pollManifestDelta() {
        val sharedPrefs = applicationContext.getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
        val deviceId = sharedPrefs.getString("device_id", null) ?: return
        val backendUrl = sharedPrefs.getString("ads_backend_url", "http://10.0.2.2:8082")
        val cachedETag = sharedPrefs.getString("cached_etag", null)

        val url = URL("$backendUrl/v1/displays/$deviceId/sync-manifest")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        if (cachedETag != null) {
            conn.setRequestProperty("If-None-Match", cachedETag)
        }

        if (conn.responseCode == 304) {
            Log.i(TAG, "Sync manifest unchanged (304 Not Modified). Preserving current offline cache.")
            return
        }

        if (conn.responseCode == 200) {
            val responseBody = conn.inputStream.bufferedReader().use { it.readText() }
            val newETag = conn.getHeaderField("ETag")
            if (newETag != null) {
                sharedPrefs.edit().putString("cached_etag", newETag).apply()
            }
            Log.i(TAG, "New manifest received from cloud authority. Processing downloads...")
        }
    }

    companion object {
        private const val TAG = "SyncWorker"
    }
}
