package com.fileflow.fileflow

import android.content.ContentResolver
import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore

/**
 * Reliable real-time detector for files created by *other* apps (the system
 * screenshot service, the browser download manager, camera, etc.).
 *
 * [FileObserver]/inotify does not report such writes on the scoped-storage FUSE
 * mount on modern Android, so we observe MediaStore instead.
 *
 * Detection uses a monotonic `_ID` watermark so each new file is emitted exactly
 * once — never re-emitting the newest rows on every notification (which would
 * flood the Dart isolate with redundant lookups). Bursts of notifications are
 * debounced into a single query.
 */
class MediaStoreWatcher(
    context: Context,
    private val onFile: (String) -> Unit,
) {
    private val resolver: ContentResolver = context.contentResolver
    private val handler = Handler(Looper.getMainLooper())
    private val filesUri: Uri = MediaStore.Files.getContentUri("external")

    private var observer: ContentObserver? = null

    // Only emit rows whose _ID is greater than this watermark.
    private var lastId: Long = -1L

    private var queryScheduled = false
    private val debounceMs = 500L
    private val debounceRunnable = Runnable {
        queryScheduled = false
        queryNew()
    }

    // Optional polling. ContentObserver.onChange is not delivered to background
    // processes on modern Android, so the background service polls MediaStore
    // directly on an interval instead.
    private var pollMs = 0L
    private val pollRunnable = object : Runnable {
        override fun run() {
            queryNew()
            if (pollMs > 0) handler.postDelayed(this, pollMs)
        }
    }

    fun enablePolling(intervalMs: Long) {
        pollMs = intervalMs
        handler.removeCallbacks(pollRunnable)
        handler.postDelayed(pollRunnable, intervalMs)
    }

    fun start() {
        if (observer != null) return
        lastId = currentMaxId()
        val obs = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                scheduleQuery()
            }
        }
        resolver.registerContentObserver(filesUri, true, obs)
        observer = obs
    }

    fun stop() {
        handler.removeCallbacks(debounceRunnable)
        handler.removeCallbacks(pollRunnable)
        pollMs = 0L
        queryScheduled = false
        observer?.let { resolver.unregisterContentObserver(it) }
        observer = null
    }

    private fun scheduleQuery() {
        if (queryScheduled) return
        queryScheduled = true
        handler.postDelayed(debounceRunnable, debounceMs)
    }

    // Highest existing _ID at start, so pre-existing files are never replayed.
    // NOTE: do NOT append "LIMIT 1" to the sort order — Android 11+ rejects it
    // for this URI, which would throw and leave the watermark at 0, causing the
    // entire media library to be treated as new. Sort DESC and read the first row.
    private fun currentMaxId(): Long {
        val projection = arrayOf(MediaStore.Files.FileColumns._ID)
        val sort = "${MediaStore.Files.FileColumns._ID} DESC"
        return try {
            resolver.query(filesUri, projection, null, null, sort)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID))
                } else {
                    0L
                }
            } ?: 0L
        } catch (_: Exception) {
            0L
        }
    }

    private fun queryNew() {
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DATA,
        )
        val selection = "${MediaStore.Files.FileColumns._ID} > ?"
        val args = arrayOf(lastId.toString())
        val sort = "${MediaStore.Files.FileColumns._ID} ASC"

        // Defense in depth: if the watermark is unset (0), this run only primes
        // it to the current max without emitting, so we can never flood the user
        // with their entire existing library as "new" files.
        val priming = lastId <= 0L

        try {
            resolver.query(filesUri, projection, selection, args, sort)?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
                val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                var maxId = lastId
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idIdx)
                    if (id > maxId) maxId = id
                    if (priming) continue
                    val path = cursor.getString(dataIdx) ?: continue
                    onFile(path)
                }
                lastId = maxId
            }
        } catch (_: Exception) {
            // Ignore transient query failures; the next tick will retry.
        }
    }
}
