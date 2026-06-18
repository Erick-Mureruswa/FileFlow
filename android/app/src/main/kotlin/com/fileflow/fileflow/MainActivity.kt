package com.fileflow.fileflow

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "fileflow/folder_picker"
    private val watcherChannel = "fileflow/file_watcher"
    private val watcherEventsChannel = "fileflow/file_watcher_events"
    private val requestCode = 1001
    private var pendingResult: MethodChannel.Result? = null

    private var fileWatcher: FileWatcher? = null
    private var mediaWatcher: MediaStoreWatcher? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickFolder") {
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, requestCode)
                } else {
                    result.notImplemented()
                }
            }

        // Real-time watchers. Events arrive on background threads, so we hop to
        // the main looper before pushing them onto the Flutter EventChannel.
        //  - FileWatcher (FileObserver): catches same-app writes and custom folders.
        //  - MediaStoreWatcher (ContentObserver): reliably catches files written
        //    by other apps (screenshots, downloads, camera) on scoped storage.
        val emit: (String) -> Unit = { path ->
            mainHandler.post { eventSink?.success(path) }
        }
        fileWatcher = FileWatcher(emit)
        mediaWatcher = MediaStoreWatcher(applicationContext, emit)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, watcherChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        fileWatcher?.start(paths)
                        mediaWatcher?.start()
                        result.success(null)
                    }
                    "stop" -> {
                        fileWatcher?.stop()
                        mediaWatcher?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, watcherEventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onDestroy() {
        fileWatcher?.stop()
        fileWatcher = null
        mediaWatcher?.stop()
        mediaWatcher = null
        super.onDestroy()
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == this.requestCode) {
            val path = if (resultCode == Activity.RESULT_OK) {
                data?.data?.let { resolveUri(it) }
            } else {
                null
            }
            pendingResult?.success(path)
            pendingResult = null
        }
    }

    private fun resolveUri(uri: Uri): String? {
        val docId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (_: Exception) {
            return null
        }
        return when {
            docId.startsWith("primary:") ->
                "/storage/emulated/0/${docId.removePrefix("primary:")}"
            docId.contains(":") -> {
                val (volume, path) = docId.split(":", limit = 2)
                "/storage/$volume/$path"
            }
            else -> null
        }
    }
}
