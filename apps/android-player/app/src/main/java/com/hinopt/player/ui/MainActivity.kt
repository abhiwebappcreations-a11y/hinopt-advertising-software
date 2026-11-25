package com.hinopt.player.ui

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.Color
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
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import com.hinopt.player.data.db.AppDatabase
import com.hinopt.player.databinding.ActivityMainBinding
import com.hinopt.player.player.PlaybackEngine
import com.hinopt.player.security.TimeSecurityManager
import com.hinopt.player.security.UsbUnlockReceiver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var timeManager: TimeSecurityManager
    private var playbackEngine: PlaybackEngine? = null
    private var pollingJob: Job? = null

    private var ownerTapCount = 0
    private var lastOwnerTapMs = 0L
    private var volTapCount = 0
    private var lastVolTapMs = 0L
    private var kioskPausedByOwner = false

    private val usbUnlockLocalReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == UsbUnlockReceiver.ACTION_USB_UNLOCK) {
                kioskPausedByOwner = true
                exitKioskMode()
                Toast.makeText(this@MainActivity, "Unlocked via USB hinopt_unlock.json!", Toast.LENGTH_LONG).show()
                moveTaskToBack(true)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        timeManager = TimeSecurityManager(this)
        setupOwnerExitGesture()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbUnlockLocalReceiver, IntentFilter(UsbUnlockReceiver.ACTION_USB_UNLOCK), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbUnlockLocalReceiver, IntentFilter(UsbUnlockReceiver.ACTION_USB_UNLOCK))
        }

        val recoveryPrefs = getSharedPreferences("hinopt_recovery", Context.MODE_PRIVATE)
        if (recoveryPrefs.getBoolean("safe_mode", false)) {
            exitKioskMode()
            showSafeModeRecoveryDialog()
            return
        }

        enterKioskMode()
        evaluateDisplayState()

        lifecycleScope.launch {
            delay(15_000L)
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

        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
                startLockTask()
            }
        } catch (e: Exception) {
            Log.w(TAG, "LockTask initiation warning: ${e.message}")
        }
    }

    private fun evaluateDisplayState() {
        // 1. Check Security Quarantine
        if (timeManager.isQuarantined()) {
            binding.quarantineOverlay.visibility = View.VISIBLE
            binding.pairingOverlay.visibility = View.GONE
            binding.emptyAdsOverlay.visibility = View.GONE
            binding.playerView.visibility = View.GONE
            return
        }

        val prefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("device_id", null)
        val status = prefs.getString("enrollment_status", "UNPAIRED")

        // Stage 1: Unpaired -> Ask for Client License Key + Screen Name
        if (deviceId == null || status == "UNPAIRED") {
            showLicenseEntryUI()
            return
        }

        // Stage 2: Submitted -> Waiting for HINOPT Super-Admin Approval
        if (status == "PENDING_APPROVAL") {
            showWaitingApprovalUI(
                prefs.getString("screen_name", "Screen") ?: "Screen",
                prefs.getString("license_key", "") ?: ""
            )
            startStatusPolling(deviceId)
            return
        }

        // Stage 3: Approved by HINOPT -> Display QR Code to Scan in Client Admin
        if (status == "APPROVED_READY_TO_SCAN") {
            val qrToken = prefs.getString("qr_token", "QR-PENDING") ?: "QR-PENDING"
            showQrScanUI(qrToken)
            startStatusPolling(deviceId)
            return
        }

        // Stage 4: Connected to Client Admin -> Play Ads or Show Empty State
        binding.pairingOverlay.visibility = View.GONE
        binding.quarantineOverlay.visibility = View.GONE
        binding.tvConnectedScreenName.text = "${prefs.getString("screen_name", "Screen")} • Connected"
        loadCachedPlaylistOrEmpty()
    }

    private fun showLicenseEntryUI() {
        binding.pairingOverlay.visibility = View.VISIBLE
        binding.licenseEntryGroup.visibility = View.VISIBLE
        binding.waitingApprovalGroup.visibility = View.GONE
        binding.qrScanGroup.visibility = View.GONE
        binding.emptyAdsOverlay.visibility = View.GONE
        binding.playerView.visibility = View.GONE
        binding.tvScreenStatus.text = "Enter the License Key from your Client Admin Panel"

        binding.btnSubmitLicense.setOnClickListener {
            val licKey = binding.etLicenseKey.text.toString().trim().uppercase()
            val screenName = binding.etScreenName.text.toString().trim()
            if (licKey.isEmpty() || screenName.isEmpty()) {
                Toast.makeText(this, "Please enter both License Key and Screen Name", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            submitScreenForApproval(licKey, screenName)
        }
    }

    private fun showWaitingApprovalUI(screenName: String, licKey: String) {
        binding.pairingOverlay.visibility = View.VISIBLE
        binding.licenseEntryGroup.visibility = View.GONE
        binding.waitingApprovalGroup.visibility = View.VISIBLE
        binding.qrScanGroup.visibility = View.GONE
        binding.emptyAdsOverlay.visibility = View.GONE
        binding.playerView.visibility = View.GONE
        binding.tvPendingInfo.text = "Screen: $screenName\nLicense: $licKey\nWaiting for HINOPT Super-Admin to click Accept..."
        binding.tvScreenStatus.text = "Checking HINOPT approval status..."
    }

    private fun showQrScanUI(qrToken: String) {
        binding.pairingOverlay.visibility = View.VISIBLE
        binding.licenseEntryGroup.visibility = View.GONE
        binding.waitingApprovalGroup.visibility = View.GONE
        binding.qrScanGroup.visibility = View.VISIBLE
        binding.emptyAdsOverlay.visibility = View.GONE
        binding.playerView.visibility = View.GONE
        binding.tvActivationCode.text = qrToken
        binding.ivQrCode.setImageBitmap(generateQrBitmap(qrToken, 512))
        binding.tvScreenStatus.text = "Waiting for Client Business Admin to confirm connection..."
    }

    private fun generateQrBitmap(content: String, size: Int): Bitmap {
        val bitMatrix = QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, size, size)
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.RGB_565)
        for (x in 0 until size) {
            for (y in 0 until size) {
                bmp.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
            }
        }
        return bmp
    }

    private fun submitScreenForApproval(licKey: String, screenName: String) {
        binding.btnSubmitLicense.isEnabled = false
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                // 1. Validate License Key in hinopt_tenants
                val tUrl = URL("$SUPABASE_URL/hinopt_tenants?tenant_id=eq.$licKey&select=*")
                val tConn = (tUrl.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("apikey", SUPABASE_KEY)
                    setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")
                }
                if (tConn.responseCode != 200) {
                    withContext(Dispatchers.Main) {
                        binding.btnSubmitLicense.isEnabled = true
                        Toast.makeText(this@MainActivity, "Network error verifying License Key", Toast.LENGTH_SHORT).show()
                    }
                    return@launch
                }
                val tArr = JSONArray(tConn.inputStream.bufferedReader().use { it.readText() })
                if (tArr.length() == 0) {
                    withContext(Dispatchers.Main) {
                        binding.btnSubmitLicense.isEnabled = true
                        Toast.makeText(this@MainActivity, "Invalid License Key! Check your Client Admin panel.", Toast.LENGTH_LONG).show()
                    }
                    return@launch
                }

                val tenant = tArr.getJSONObject(0)
                val tenantUuid = tenant.getString("id")
                val expiryIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }.format(Date(System.currentTimeMillis() + 730L * 24 * 60 * 60 * 1000))
                val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN"

                // 2. Register screen in PENDING_APPROVAL state
                val sUrl = URL("$SUPABASE_URL/hinopt_screens")
                val sConn = (sUrl.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("apikey", SUPABASE_KEY)
                    setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Prefer", "return=representation")
                    doOutput = true
                }
                val body = JSONObject().apply {
                    put("tenant_id", tenantUuid)
                    put("enrollment_status", "PENDING_APPROVAL")
                    put("screen_name", screenName)
                    put("hardware_model", Build.MODEL)
                    put("android_id", androidId)
                    put("license_tier", "PRO")
                    put("license_expires_at", expiryIso)
                }
                OutputStreamWriter(sConn.outputStream).use { it.write(body.toString()) }

                if (sConn.responseCode in 200..299) {
                    val createdArr = JSONArray(sConn.inputStream.bufferedReader().use { it.readText() })
                    val screenId = createdArr.getJSONObject(0).getString("id")
                    getSharedPreferences("hinopt_device", Context.MODE_PRIVATE).edit()
                        .putString("device_id", screenId)
                        .putString("tenant_id", tenantUuid)
                        .putString("license_key", licKey)
                        .putString("screen_name", screenName)
                        .putString("enrollment_status", "PENDING_APPROVAL")
                        .apply()

                    withContext(Dispatchers.Main) {
                        binding.btnSubmitLicense.isEnabled = true
                        evaluateDisplayState()
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        binding.btnSubmitLicense.isEnabled = true
                        Toast.makeText(this@MainActivity, "Registration failed (${sConn.responseCode})", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    binding.btnSubmitLicense.isEnabled = true
                    Toast.makeText(this@MainActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun startStatusPolling(screenId: String) {
        pollingJob?.cancel()
        pollingJob = lifecycleScope.launch(Dispatchers.IO) {
            while (true) {
                try {
                    val url = URL("$SUPABASE_URL/hinopt_screens?id=eq.$screenId&select=*")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        connectTimeout = 4000
                        readTimeout = 4000
                        setRequestProperty("apikey", SUPABASE_KEY)
                        setRequestProperty("Authorization", "Bearer $SUPABASE_KEY")
                    }
                    if (conn.responseCode == 200) {
                        val arr = JSONArray(conn.inputStream.bufferedReader().use { it.readText() })
                        if (arr.length() > 0) {
                            val row = arr.getJSONObject(0)
                            val newStatus = row.getString("enrollment_status")
                            val qrToken = row.optString("activation_code", "")
                            val prefs = getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
                            val oldStatus = prefs.getString("enrollment_status", "")

                            if (newStatus != oldStatus) {
                                prefs.edit()
                                    .putString("enrollment_status", newStatus)
                                    .putString("qr_token", qrToken)
                                    .apply()
                                withContext(Dispatchers.Main) {
                                    evaluateDisplayState()
                                }
                                if (newStatus == "CONNECTED" || newStatus == "ACTIVE" || newStatus == "REVOKED") break
                            }
                        }
                    }
                } catch (_: Exception) {}
                delay(4000L)
            }
        }
    }

    private fun loadCachedPlaylistOrEmpty() {
        lifecycleScope.launch(Dispatchers.IO) {
            val db = AppDatabase.getInstance(this@MainActivity)
            val items = db.playlistItemDao().getPlayableItems()

            withContext(Dispatchers.Main) {
                if (items.isEmpty()) {
                    binding.emptyAdsOverlay.visibility = View.VISIBLE
                    binding.playerView.visibility = View.GONE
                } else {
                    binding.emptyAdsOverlay.visibility = View.GONE
                    binding.playerView.visibility = View.VISIBLE
                    if (playbackEngine == null) {
                        playbackEngine = PlaybackEngine(this@MainActivity, binding.playerView, lifecycleScope)
                    }
                    playbackEngine?.submitPlaylist(items)
                }
            }
        }
    }

    private fun setupOwnerExitGesture() {
        binding.ownerExitTouchZone.setOnClickListener {
            val now = System.currentTimeMillis()
            ownerTapCount = if (now - lastOwnerTapMs > 3000L) 1 else ownerTapCount + 1
            lastOwnerTapMs = now
            if (ownerTapCount >= 5) {
                ownerTapCount = 0
                showOwnerPinDialog()
            }
        }
    }

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

    private fun showOwnerPinDialog() {
        val pinInput = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = "Enter 6-digit Owner PIN (Default: 202600)"
        }

        AlertDialog.Builder(this)
            .setTitle("HINOPT Owner / Technician Access")
            .setMessage("Enter PIN to quit software back to main screen or manage device.")
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
            "Quit Software Back to Main Screen",
            "Open Android Wi-Fi & Device Settings",
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
                    2 -> {
                        pollingJob?.cancel()
                        getSharedPreferences("hinopt_device", Context.MODE_PRIVATE).edit().clear().apply()
                        playbackEngine?.release()
                        playbackEngine = null
                        evaluateDisplayState()
                        Toast.makeText(this, "Screen reset. Enter License Key to re-register.", Toast.LENGTH_SHORT).show()
                    }
                    3 -> {
                        kioskPausedByOwner = false
                        enterKioskMode()
                    }
                }
            }
            .show()
    }

    private fun showSafeModeRecoveryDialog() {
        AlertDialog.Builder(this)
            .setTitle("HINOPT Safe Mode (Crash Guard)")
            .setMessage("Repeated app crashes were detected. Kiosk lock has been disabled so you can recover the screen.")
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

    private fun exitKioskMode() {
        try {
            stopLockTask()
        } catch (e: Exception) {
            Log.w(TAG, "LockTask exit warning: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        pollingJob?.cancel()
        try {
            unregisterReceiver(usbUnlockLocalReceiver)
        } catch (_: Exception) {}
        playbackEngine?.release()
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val DEFAULT_OWNER_PIN = "202600"
        private const val SUPABASE_URL = "https://yqmczojypjzsvbngipwd.supabase.co/rest/v1"
        private const val SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlxbWN6b2p5cGp6c3ZibmdpcHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU1MzY4ODcsImV4cCI6MjExMTExMjg4N30._B6VY5pwF7ODJyh5vh1rJ3GprIMkcAvNbxjLn5vt5BQ"
    }
}
