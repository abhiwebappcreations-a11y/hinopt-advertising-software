package com.hinopt.player.ui

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.hinopt.player.data.db.AppDatabase
import com.hinopt.player.databinding.ActivityMainBinding
import com.hinopt.player.player.PlaybackEngine
import com.hinopt.player.security.TimeSecurityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
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
        setupOwnerExitGesture()

        val recoveryPrefs = getSharedPreferences("hinopt_recovery", Context.MODE_PRIVATE)
        if (recoveryPrefs.getBoolean("safe_mode", false)) {
            exitKioskMode()
            showSafeModeRecoveryDialog()
            return
        }

        enterKioskMode()
        evaluateDisplayState()

        // Reset crash-loop counter if player runs stably for 15 seconds
        lifecycleScope.launch {
            kotlinx.coroutines.delay(15_000L)
            recoveryPrefs.edit().putInt("crash_count", 0).apply()
        }
    }

    override fun onResume() {
        super.onResume()
        val recoveryPrefs = getSharedPreferences("hinopt_recovery", Context.MODE_PRIVATE)
        if (!kioskPausedByOwner && !recoveryPrefs.getBoolean("safe_mode", false)) {
            enterKioskMode()
        }
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
            binding.tvScreenStatus.text = "Waiting for Super-Admin pairing • Connected to HINOPT Cloud"
            binding.pairingOverlay.visibility = View.VISIBLE
            binding.playerView.visibility = View.GONE
            Log.i(TAG, "Device unpaired. Displaying activation code: $code")
            startEnrollmentPolling(code)
            return
        }

        // 3. Screen is registered and active: Launch ExoPlayer engine
        binding.pairingOverlay.visibility = View.GONE
        binding.quarantineOverlay.visibility = View.GONE
        binding.playerView.visibility = View.VISIBLE

        playbackEngine = PlaybackEngine(this, binding.playerView, lifecycleScope)
        loadCachedPlaylist()
    }

    private var enrollmentJob: kotlinx.coroutines.Job? = null

    private fun startEnrollmentPolling(code: String) {
        enrollmentJob?.cancel()
        enrollmentJob = lifecycleScope.launch(Dispatchers.IO) {
            while (true) {
                try {
                    val sharedPrefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
                    if (sharedPrefs.getString("device_id", null) != null) break

                    val queryUrl = URL("$SUPABASE_URL/hinopt_screens?activation_code=eq.$code&enrollment_status=eq.PRE_AUTHORIZED&select=*")
                    val getConn = (queryUrl.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        connectTimeout = 5000
                        readTimeout = 5000
                        setRequestProperty("apikey", SUPABASE_KEY)
                        setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")
                    }

                    if (getConn.responseCode == 200) {
                        val body = getConn.inputStream.bufferedReader().use { it.readText() }
                        val arr = org.json.JSONArray(body)
                        if (arr.length() > 0) {
                            val screen = arr.getJSONObject(0)
                            val screenId = screen.getString("id")
                            val tenantId = screen.getString("tenant_id")

                            // Activate screen directly in Supabase Cloud
                            val patchUrl = URL("$SUPABASE_URL/hinopt_screens?id=eq.$screenId")
                            val patchConn = (patchUrl.openConnection() as HttpURLConnection).apply {
                                requestMethod = "PATCH"
                                connectTimeout = 5000
                                readTimeout = 5000
                                setRequestProperty("apikey", SUPABASE_KEY)
                                setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")
                                setRequestProperty("Content-Type", "application/json")
                                doOutput = true
                            }
                            val nowIso = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).apply {
                                timeZone = java.util.TimeZone.getTimeZone("UTC")
                            }.format(java.util.Date())
                            val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN"
                            val patchPayload = """{"enrollment_status":"ACTIVE","hardware_model":"${Build.MODEL}","android_id":"$androidId","activation_code":null,"last_heartbeat_at":"$nowIso"}"""
                            OutputStreamWriter(patchConn.outputStream).use { it.write(patchPayload) }

                            if (patchConn.responseCode in 200..299) {
                                sharedPrefs.edit()
                                    .putString("device_id", screenId)
                                    .putString("tenant_id", tenantId)
                                    .apply()
                                withContext(Dispatchers.Main) {
                                    Toast.makeText(this@MainActivity, "Screen Paired to HINOPT Cloud!", Toast.LENGTH_LONG).show()
                                    evaluateDisplayState()
                                }
                                break
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Cloud pairing poll retry: ${e.message}")
                }
                kotlinx.coroutines.delay(4000L)
            }
        }
    }

    private fun showServerIpDialog() {
        val sharedPrefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
        val ipInput = EditText(this).apply {
            setText(sharedPrefs.getString("server_ip", DEFAULT_SERVER_IP))
            hint = "e.g. 10.149.241.51"
        }
        AlertDialog.Builder(this)
            .setTitle("Backend Server IP")
            .setMessage("Enter your PC's Wi-Fi IPv4 address (running node scripts/start-all.js):")
            .setView(ipInput)
            .setPositiveButton("Save") { _, _ ->
                val newIp = ipInput.text.toString().trim()
                if (newIp.isNotEmpty()) {
                    sharedPrefs.edit().putString("server_ip", newIp).apply()
                    evaluateDisplayState()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
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

    private var ownerTapCount = 0
    private var lastOwnerTapMs = 0L
    private var volTapCount = 0
    private var lastVolTapMs = 0L
    private var kioskPausedByOwner = false

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val now = System.currentTimeMillis()
            volTapCount = if (now - lastVolTapMs > 3000L) 1 else volTapCount + 1
            lastVolTapMs = now
            if (volTapCount >= 5) {
                volTapCount = 0
                showOwnerPinDialog()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun showSafeModeRecoveryDialog() {
        AlertDialog.Builder(this)
            .setTitle("HINOPT Safe Mode (Crash Guard)")
            .setMessage("Repeated app crashes were detected. Kiosk lock has been automatically disabled so you can safely recover or update the device.")
            .setCancelable(false)
            .setPositiveButton("Open Android Settings") { _, _ ->
                kioskPausedByOwner = true
                startActivity(Intent(Settings.ACTION_SETTINGS))
            }
            .setNeutralButton("Retry Player") { _, _ ->
                getSharedPreferences("hinopt_recovery", Context.MODE_PRIVATE)
                    .edit().putBoolean("safe_mode", false).putInt("crash_count", 0).apply()
                kioskPausedByOwner = false
                enterKioskMode()
                evaluateDisplayState()
            }
            .setNegativeButton("Exit App") { _, _ ->
                kioskPausedByOwner = true
                finishAndRemoveTask()
            }
            .show()
    }

    private fun setupOwnerExitGesture() {
        binding.ownerExitTouchZone.setOnClickListener {
            val now = System.currentTimeMillis()
            if (now - lastOwnerTapMs > 3000L) {
                ownerTapCount = 1
            } else {
                ownerTapCount++
            }
            lastOwnerTapMs = now

            if (ownerTapCount >= 5) {
                ownerTapCount = 0
                showOwnerPinDialog()
            }
        }
    }

    private fun showOwnerPinDialog() {
        val pinInput = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "Enter 6-digit Owner PIN"
        }

        AlertDialog.Builder(this)
            .setTitle("HINOPT Owner / Technician Access")
            .setMessage("Enter the authorized technician PIN to exit kiosk lock or manage this screen.")
            .setView(pinInput)
            .setPositiveButton("Unlock") { _, _ ->
                val sharedPrefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
                val expectedPin = sharedPrefs.getString("owner_pin", DEFAULT_OWNER_PIN) ?: DEFAULT_OWNER_PIN
                if (pinInput.text.toString().trim() == expectedPin) {
                    showOwnerActionsDialog()
                } else {
                    Toast.makeText(this, "Invalid Owner PIN", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showOwnerActionsDialog() {
        val options = arrayOf(
            "Exit Kiosk to Android Home",
            "Open Android Wi-Fi & Device Settings",
            "Configure Backend Server IP",
            "Reset / Unpair Screen",
            "Resume Kiosk Mode"
        )

        AlertDialog.Builder(this)
            .setTitle("Screen Owner Controls")
            .setItems(options) { _, which ->
                when (which) {
                    0 -> {
                        kioskPausedByOwner = true
                        exitKioskMode()
                        moveTaskToBack(true)
                    }
                    1 -> {
                        kioskPausedByOwner = true
                        exitKioskMode()
                        startActivity(Intent(Settings.ACTION_SETTINGS))
                    }
                    2 -> showServerIpDialog()
                    3 -> {
                        val sharedPrefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
                        sharedPrefs.edit().remove("device_id").remove("activation_code").apply()
                        playbackEngine?.release()
                        playbackEngine = null
                        evaluateDisplayState()
                        Toast.makeText(this, "Screen unpaired. Ready for new pairing code.", Toast.LENGTH_SHORT).show()
                    }
                    4 -> {
                        kioskPausedByOwner = false
                        enterKioskMode()
                    }
                }
            }
            .show()
    }

    private fun exitKioskMode() {
        try {
            stopLockTask()
            Log.i(TAG, "Exited Android Kiosk LockTask mode via Owner PIN.")
        } catch (e: Exception) {
            Log.w(TAG, "LockTask exit warning: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        playbackEngine?.release()
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val DEFAULT_OWNER_PIN = "202600"
        private const val DEFAULT_SERVER_IP = "10.149.241.51"
        private const val SUPABASE_URL = "https://yqmczojypjzsvbngipwd.supabase.co/rest/v1"
        private const val SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxbWN6b2p5cGp6c3ZibmdpcHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzY4ODcsImV4cCI6MjExMTExMjg4N30._B6VY5pwF7ODJyh5vh1rJ3GprIMkcAvNbxjLn5vt5BQ"
    }
}
