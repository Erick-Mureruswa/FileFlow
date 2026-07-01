package com.fileflow.fileflow

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File

/** Result of tracking a newly arrived file, used to build a notification. */
data class TrackResult(val fileId: Long, val name: String, val folderName: String)

/**
 * Native equivalent of the Dart FileArrivalService. Used by the background
 * foreground service to track files while the app UI is closed, writing to the
 * same SQLite database the app uses.
 */
object FileTracker {
    private val partialExtensions =
        listOf(".tmp", ".part", ".crdownload", ".download", ".pending", ".opdownload")
    private val imageExt =
        setOf("jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "avif", "tiff")
    private val videoExt = setOf("mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "3gp", "m4v")
    private val docExt = setOf(
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "txt", "csv", "odt", "ods", "odp", "rtf", "md",
    )
    private val audioExt = setOf("mp3", "wav", "flac", "aac", "m4a", "ogg", "wma", "opus")
    private val archiveExt = setOf("zip", "rar", "tar", "gz", "7z", "bz2", "xz")

    private const val DAY_MS = 86_400_000L

    fun track(context: Context, path: String): TrackResult? {
        val name = path.substringAfterLast('/')
        if (name.isEmpty() || name.startsWith(".")) return null
        val lower = name.lowercase()
        if (partialExtensions.any { lower.endsWith(it) }) return null
        if (lower.startsWith("thumbnail_")) return null

        val file = File(path)
        if (!file.exists() || !file.isFile) return null

        val db = openDb(context) ?: return null
        try {
            var folderId = -1L
            var folderName = ""
            var retentionDays = 0
            var bestLen = -1
            db.rawQuery(
                "SELECT id, path, display_name, default_retention_days " +
                    "FROM monitored_folders WHERE is_enabled = 1",
                null,
            ).use { c ->
                while (c.moveToNext()) {
                    val fPath = c.getString(1)
                    if (path.startsWith("$fPath/") && fPath.length > bestLen) {
                        bestLen = fPath.length
                        folderId = c.getLong(0)
                        folderName = c.getString(2)
                        retentionDays = c.getInt(3)
                    }
                }
            }
            if (folderId < 0) return null

            db.rawQuery("SELECT id FROM tracked_files WHERE path = ?", arrayOf(path)).use { c ->
                if (c.moveToFirst()) return null // already tracked
            }

            val now = System.currentTimeMillis()
            val values = ContentValues().apply {
                put("path", path)
                put("name", name)
                put("size", file.length())
                put("file_type", detectType(name))
                put("folder_id", folderId)
                put("detected_at", now)
                if (retentionDays > 0) put("expires_at", now + retentionDays * DAY_MS)
                else putNull("expires_at")
                put("is_starred", 0)
                put("is_deleted", 0)
            }
            val id = db.insert("tracked_files", null, values)
            if (id <= 0) return null
            return TrackResult(id, name, folderName)
        } catch (_: Exception) {
            return null
        } finally {
            db.close()
        }
    }

    fun star(context: Context, fileId: Long) {
        val db = openDb(context) ?: return
        try {
            val values = ContentValues().apply { put("is_starred", 1) }
            db.update("tracked_files", values, "id = ?", arrayOf(fileId.toString()))
        } catch (_: Exception) {
            // ignore
        } finally {
            db.close()
        }
    }

    private fun openDb(context: Context): SQLiteDatabase? {
        val f = context.getDatabasePath("fileflow.db")
        if (!f.exists()) return null
        return try {
            val db = SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READWRITE)
            // Wait rather than fail if the app holds a brief lock.
            db.rawQuery("PRAGMA busy_timeout = 4000", null).use { it.moveToFirst() }
            db
        } catch (_: Exception) {
            null
        }
    }

    private fun detectType(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return when (ext) {
            in imageExt -> "image"
            in videoExt -> "video"
            in docExt -> "document"
            in audioExt -> "audio"
            in archiveExt -> "archive"
            else -> "other"
        }
    }
}
