package com.fileflow.fileflow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps FileFlow watching the user's folders even when
 * the app UI is closed. It observes MediaStore for new files (screenshots,
 * downloads, camera, etc.), tracks them in the database, and posts a Star /
 * Ignore notification. Detection is skipped while the app is in the foreground,
 * where the in-app popup handles it instead.
 */
class MonitorService : Service() {
    private var watcher: MediaStoreWatcher? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(FG_ID, buildOngoingNotification())
        watcher = MediaStoreWatcher(applicationContext) { path ->
            // App visible: the in-app popup handles arrivals; skip to avoid duplicates.
            if (AppState.isForeground) return@MediaStoreWatcher
            val result = FileTracker.track(applicationContext, path)
            if (result != null) ArrivalNotifier.show(applicationContext, result)
        }
        watcher?.start()
        // Background processes do not receive MediaStore change callbacks, so
        // poll on an interval while the service keeps the process alive.
        watcher?.enablePolling(POLL_MS)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        watcher?.stop()
        watcher = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildOngoingNotification(): Notification {
        ensureChannel(this)
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ONGOING)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("FileFlow is watching your folders")
            .setContentText("New screenshots and downloads are tracked automatically")
            .setOngoing(true)
            .setContentIntent(open)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        const val FG_ID = 4200
        const val CHANNEL_ONGOING = "fileflow_monitor"
        private const val POLL_MS = 15_000L

        fun start(context: Context) {
            val intent = Intent(context, MonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MonitorService::class.java))
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(NotificationManager::class.java)
                if (nm.getNotificationChannel(CHANNEL_ONGOING) == null) {
                    nm.createNotificationChannel(
                        NotificationChannel(
                            CHANNEL_ONGOING,
                            "Folder monitoring",
                            NotificationManager.IMPORTANCE_LOW,
                        ).apply {
                            description = "Keeps FileFlow watching your folders in the background"
                            setShowBadge(false)
                        },
                    )
                }
            }
        }
    }
}
