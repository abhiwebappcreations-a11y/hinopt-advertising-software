package com.hinopt.player.security

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log

enum class TimeState {
    TIME_SYNCHRONIZED,
    CONTINUOUS_OFFLINE,
    UNTRUSTED_OFFLINE_REBOOT,
    CLOCK_ROLLBACK_QUARANTINE
}

class TimeSecurityManager(context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private var currentState: TimeState = TimeState.UNTRUSTED_OFFLINE_REBOOT

    init {
        evaluateTimeIntegrity()
    }

    /**
     * Evaluates clock monotonicity and detects offline rollbacks.
     */
    fun evaluateTimeIntegrity(): TimeState {
        val lastTrustedTime = prefs.getLong(KEY_LAST_TRUSTED_TIME, 0L)
        val lastElapsedRealtime = prefs.getLong(KEY_LAST_ELAPSED_REALTIME, 0L)
        val currentTime = System.currentTimeMillis()
        val currentElapsed = SystemClock.elapsedRealtime()

        // 1. Detect Clock Rollback: if wall-clock jumped backwards more than 60 seconds
        if (lastTrustedTime > 0 && currentTime < (lastTrustedTime - 60_000L)) {
            Log.e(TAG, "CLOCK ROLLBACK DETECTED! lastTrusted=$lastTrustedTime, currentTime=$currentTime")
            currentState = TimeState.CLOCK_ROLLBACK_QUARANTINE
            return currentState
        }

        // 2. Check if continuous offline or post-reboot
        if (currentElapsed > lastElapsedRealtime && lastElapsedRealtime > 0) {
            currentState = TimeState.CONTINUOUS_OFFLINE
        } else {
            currentState = TimeState.UNTRUSTED_OFFLINE_REBOOT
        }

        // Update trusted anchor
        recordTrustedTime(currentTime)
        return currentState
    }

    /**
     * Called when authoritative server time is received via Heartbeat.
     */
    fun onAuthoritativeServerTimeReceived(serverTimeMillis: Long) {
        val localTime = System.currentTimeMillis()
        val drift = Math.abs(serverTimeMillis - localTime)

        Log.i(TAG, "Synchronized with HINOPT Authority. Drift: ${drift}ms")
        recordTrustedTime(serverTimeMillis)
        currentState = TimeState.TIME_SYNCHRONIZED
    }

    fun recordTrustedTime(timeMillis: Long) {
        prefs.edit()
            .putLong(KEY_LAST_TRUSTED_TIME, Math.max(timeMillis, System.currentTimeMillis()))
            .putLong(KEY_LAST_ELAPSED_REALTIME, SystemClock.elapsedRealtime())
            .apply()
    }

    fun isQuarantined(): Boolean = currentState == TimeState.CLOCK_ROLLBACK_QUARANTINE

    fun getCurrentState(): TimeState = currentState

    companion object {
        private const val TAG = "TimeSecurityManager"
        private const val PREFS_NAME = "hinopt_time_security"
        private const val KEY_LAST_TRUSTED_TIME = "last_trusted_wall_time"
        private const val KEY_LAST_ELAPSED_REALTIME = "last_elapsed_realtime"
    }
}
