package com.hinopt.player.ui

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.hinopt.player.data.db.AppDatabase
import com.hinopt.player.databinding.ActivityMainBinding
import com.hinopt.player.player.PlaybackEngine
import com.hinopt.player.security.TimeSecurityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Random

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var timeManager: TimeSecurityManager
    private var playbackEngine: PlaybackEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        timeManager = TimeSecurityManager(this)

        enterKioskMode()
        evaluateDisplayState()
    }

    private fun enterKioskMode() {
        // Hide system status and navigation bars (Immersive Mode)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }

        // Start Android LockTask mode if permitted as Device Owner
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
                startLockTask()
                Log.i(TAG, "Entered Android Kiosk LockTask mode successfully.")
            }
        } catch (e: Exception) {
            Log.w(TAG, "LockTask initiation warning: ${e.message}")
        }
    }

    private fun evaluateDisplayState() {
        // 1. Check Security Quarantine (Clock Rollback)
        if (timeManager.isQuarantined()) {
            binding.quarantineOverlay.visibility = View.VISIBLE
            binding.pairingOverlay.visibility = View.GONE
            Log.e(TAG, "Screen in CLOCK_ROLLBACK_QUARANTINE. Playback halted.")
            return
        }

        // 2. Check Device Registration (Zero Demo Data Clean Invariant)
        val sharedPrefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
        val deviceId = sharedPrefs.getString("device_id", null)

        if (deviceId == null) {
            // Unpaired screen: Generate or retrieve 6-character activation code
            var code = sharedPrefs.getString("activation_code", null)
            if (code == null) {
                code = generateActivationCode()
                sharedPrefs.edit().putString("activation_code", code).apply()
            }

            binding.tvActivationCode.text = code
            binding.pairingOverlay.visibility = View.VISIBLE
            binding.playerView.visibility = View.GONE
            Log.i(TAG, "Device unpaired. Displaying activation code: $code")
            return
        }

        // 3. Screen is registered and active: Launch ExoPlayer engine
        binding.pairingOverlay.visibility = View.GONE
        binding.quarantineOverlay.visibility = View.GONE
        binding.playerView.visibility = View.VISIBLE

        playbackEngine = PlaybackEngine(this, binding.playerView, lifecycleScope)
        loadCachedPlaylist()
    }

    private fun loadCachedPlaylist() {
        lifecycleScope.launch(Dispatchers.IO) {
            val db = AppDatabase.getInstance(this@MainActivity)
            val items = db.playlistItemDao().getPlayableItems()

            withContext(Dispatchers.Main) {
                playbackEngine?.submitPlaylist(items)
            }
        }
    }

    private fun generateActivationCode(): String {
        val chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
        val rnd = Random()
        val sb = StringBuilder(6)
        for (i in 0 until 6) {
            sb.append(chars[rnd.nextInt(chars.length)])
        }
        return sb.toString()
    }

    override fun onDestroy() {
        super.onDestroy()
        playbackEngine?.release()
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
