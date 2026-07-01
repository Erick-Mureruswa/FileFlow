package com.fileflow.fileflow

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Posts the background equivalent of the in-app arrival popup: a notification
 * for a newly tracked file with Star and Ignore actions.
 */
object ArrivalNotifier {
    const val CHANNEL = "fileflow_arrivals"

    fun show(context: Context, result: TrackResult) {
        ensureChannel(context)

        val base = (result.fileId % 900_000L).toInt() + 1000
        val star = broadcast(context, base, MonitorActionReceiver.ACTION_STAR) {
            putExtra(MonitorActionReceiver.EXTRA_FILE_ID, result.fileId)
            putExtra(MonitorActionReceiver.EXTRA_NOTIF_ID, base)
        }
        val ignore = broadcast(context, base + 1, MonitorActionReceiver.ACTION_IGNORE) {
            putExtra(MonitorActionReceiver.EXTRA_NOTIF_ID, base)
        }
        val open = PendingIntent.getActivity(
            context,
            base + 2,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("New file detected")
            .setContentText("${result.name}  ·  ${result.folderName}")
            .setStyle(NotificationCompat.BigTextStyle().bigText("${result.name}\n${result.folderName}"))
            .setAutoCancel(true)
            .setContentIntent(open)
            .addAction(0, "Star", star)
            .addAction(0, "Ignore", ignore)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(base, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted; the file is still tracked.
        }
    }

    private fun broadcast(
        context: Context,
        requestCode: Int,
        action: String,
        extras: Intent.() -> Unit,
    ): PendingIntent {
        val intent = Intent(context, MonitorActionReceiver::class.java).setAction(action).apply(extras)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL,
                        "New file alerts",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply { description = "Prompts to keep or ignore files found in the background" },
                )
            }
        }
    }
}
