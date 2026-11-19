package com.hinopt.player

import android.app.Application
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
        Log.i(TAG, "HINOPT Display Player Application initialized.")
        schedulePeriodicSync()
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
