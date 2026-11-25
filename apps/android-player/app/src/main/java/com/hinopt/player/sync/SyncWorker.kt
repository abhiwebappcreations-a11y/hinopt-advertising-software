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

        Log.i(TAG, "Uploading ${pending.size} proof-of-play impression records to Supabase Cloud...")
        val sharedPrefs = applicationContext.getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
        val deviceId = sharedPrefs.getString("device_id", null) ?: return

        val url = URL("$SUPABASE_URL/ads_proof_of_play")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("apikey", SUPABASE_KEY)
        conn.setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true

        val arr = JSONArray()
        pending.forEach { p ->
            arr.put(JSONObject().apply {
                put("screen_id", deviceId)
                put("campaign_id", p.campaign_id)
                put("asset_id", p.asset_id)
                put("play_date", p.play_date)
                put("completed_impressions", p.completed_impressions)
                put("total_seconds_played", p.total_seconds_played)
                put("interrupted_impressions", p.interrupted_impressions)
            })
        }

        conn.outputStream.use { os ->
            os.write(arr.toString().toByteArray())
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

        val url = URL("$SUPABASE_URL/ads_campaigns?status=eq.ACTIVE&select=*,ads_creatives(*)")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.setRequestProperty("apikey", SUPABASE_KEY)
        conn.setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")

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
        private const val SUPABASE_URL = "https://yqmczojypjzsvbngipwd.supabase.co/rest/v1"
        private const val SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxbWN6b2p5cGp6c3ZibmdpcHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzY4ODcsImV4cCI6MjExMTExMjg4N30._B6VY5pwF7ODJyh5vh1rJ3GprIMkcAvNbxjLn5vt5BQ"
    }
}
