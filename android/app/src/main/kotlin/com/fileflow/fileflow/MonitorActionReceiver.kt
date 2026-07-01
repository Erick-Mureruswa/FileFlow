package com.fileflow.fileflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

/** Handles the Star / Ignore actions on a background arrival notification. */
class MonitorActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notifId = intent.getIntExtra(EXTRA_NOTIF_ID, -1)

        if (intent.action == ACTION_STAR) {
            val fileId = intent.getLongExtra(EXTRA_FILE_ID, -1L)
            if (fileId > 0) FileTracker.star(context, fileId)
        }
        // Ignore just dismisses; the file keeps its default retention rule.

        if (notifId > 0) NotificationManagerCompat.from(context).cancel(notifId)
    }

    companion object {
        const val ACTION_STAR = "com.fileflow.fileflow.STAR"
        const val ACTION_IGNORE = "com.fileflow.fileflow.IGNORE"
        const val EXTRA_FILE_ID = "fileId"
        const val EXTRA_NOTIF_ID = "notifId"
    }
}
