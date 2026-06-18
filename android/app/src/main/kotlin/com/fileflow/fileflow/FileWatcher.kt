package com.fileflow.fileflow

import android.os.FileObserver
import java.io.File

/**
 * Watches a set of directories for newly arrived files using Android's
 * [FileObserver]. One observer is created per directory.
 *
 * Detection happens in real time while the app process is alive. We only react
 * to events that signal a *complete* file:
 *  - CLOSE_WRITE  → a file finished being written (new file, download, copy)
 *  - MOVED_TO     → a file was moved/renamed into the folder
 *
 * The deprecated String-path constructor is used intentionally so the watcher
 * works on API 24+ (the File constructor is API 29+). Watching is non-recursive,
 * which matches the flat-folder scan used elsewhere in the app.
 */
class FileWatcher(private val onFile: (String) -> Unit) {
    private val observers = mutableListOf<FileObserver>()

    private val mask = FileObserver.CLOSE_WRITE or FileObserver.MOVED_TO

    fun start(paths: List<String>) {
        stop()
        for (path in paths) {
            val dir = File(path)
            if (!dir.isDirectory) continue
            val observer = createObserver(path)
            observer.startWatching()
            observers.add(observer)
        }
    }

    fun stop() {
        for (observer in observers) observer.stopWatching()
        observers.clear()
    }

    @Suppress("DEPRECATION")
    private fun createObserver(dirPath: String): FileObserver {
        return object : FileObserver(dirPath, mask) {
            override fun onEvent(event: Int, path: String?) {
                if (path == null) return
                val relevant = event and (CLOSE_WRITE or MOVED_TO)
                if (relevant == 0) return
                onFile("$dirPath/$path")
            }
        }
    }
}
