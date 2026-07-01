package com.fileflow.fileflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts background monitoring after a reboot, if the user has it enabled.
 * Reads the same SharedPreferences the Flutter app writes (keys are prefixed
 * with "flutter.").
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val enabled = prefs.getBoolean("flutter.bg_monitor_enabled", true)
        if (enabled) MonitorService.start(context)
    }
}
