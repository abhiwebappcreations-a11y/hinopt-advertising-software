package com.hinopt.player.boot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.hinopt.player.ui.MainActivity

class BootCompletedReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "Received system broadcast action: $action")

        if (Intent.ACTION_BOOT_COMPLETED == action ||
            "android.intent.action.QUICKBOOT_POWERON" == action ||
            Intent.ACTION_POWER_CONNECTED == action) {

            Log.i(TAG, "Vehicle ignition / AC power detected. Auto-launching HINOPT Kiosk within 10s...")
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(launchIntent)
        }
    }

    companion object {
        private const val TAG = "BootCompletedReceiver"
    }
}
