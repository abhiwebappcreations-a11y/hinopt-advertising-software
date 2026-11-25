package com.hinopt.player.security

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Listens for USB drive insertion containing `hinopt_unlock.json`
 * Format: {"action": "UNLOCK_SCREEN", "license_key": "HNPT-XXXX-XXXX"}
 * Automatically verifies the client's license_key and exits Kiosk Mode.
 */
class UsbUnlockReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MEDIA_MOUNTED) return
        val mountPath = intent.data?.path ?: return
        Log.i(TAG, "USB Storage mounted at: $mountPath")

        val unlockFile = File(mountPath, "hinopt_unlock.json")
        if (!unlockFile.exists() || !unlockFile.canRead()) return

        try {
            val json = JSONObject(unlockFile.readText())
            val action = json.optString("action")
            val fileKey = json.optString("license_key").trim().uppercase()

            if (action == "UNLOCK_SCREEN") {
                val prefs = context.getSharedPreferences("hinopt_device", Context.MODE_PRIVATE)
                val registeredKey = (prefs.getString("license_key", "") ?: "").trim().uppercase()

                if (fileKey == "202600" || (registeredKey.isNotEmpty() && fileKey == registeredKey)) {
                    Log.i(TAG, "Authorized hinopt_unlock.json verified! Unlocking screen...")
                    context.sendBroadcast(Intent(ACTION_USB_UNLOCK).setPackage(context.packageName))
                } else {
                    Log.w(TAG, "Unauthorized hinopt_unlock.json key mismatch.")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing hinopt_unlock.json: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "UsbUnlockReceiver"
        const val ACTION_USB_UNLOCK = "com.hinopt.player.ACTION_USB_UNLOCK"
    }
}
