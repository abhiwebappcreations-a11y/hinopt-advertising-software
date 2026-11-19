package com.hinopt.player.security

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class KioskAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i(TAG, "HINOPT Display Player Device Admin Enabled.")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.w(TAG, "HINOPT Display Player Device Admin Disabled!")
    }

    companion object {
        private const val TAG = "KioskAdminReceiver"
    }
}
