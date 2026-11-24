package com.hinopt.player

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.work.Configuration
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.hinopt.player.sync.SyncWorker
import java.util.concurrent.TimeUnit

class HinoptApplication : Application(), Configuration.Provider {

    override fun onCreate() {
        super.onCreate()
        installCrashLoopGuard()
        Log.i(TAG, "HINOPT Display Player Application initialized.")
        schedulePeriodicSync()
    }

    private fun installCrashLoopGuard() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val prefs = getSharedPreferences("hinopt_recovery", Context.MODE_PRIVATE)
                val now = System.currentTimeMillis()
                val lastCrash = prefs.getLong("last_crash_ms", 0L)
                val count = if (now - lastCrash < 30_000L) prefs.getInt("crash_count", 0) + 1 else 1
                prefs.edit()
                    .putLong("last_crash_ms", now)
                    .putInt("crash_count", count)
                    .putBoolean("safe_mode", count >= 3)
                    .commit()
            } catch (_: Exception) {}
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun schedulePeriodicSync() {
        val syncRequest = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "hinopt_signage_sync",
            ExistingPeriodicWorkPolicy.KEEP,
            syncRequest
        )
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.INFO)
            .build()

    companion object {
        const val TAG = "HINOPT_APP"
    }
}
