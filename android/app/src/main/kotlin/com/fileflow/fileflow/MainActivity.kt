package com.fileflow.fileflow

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "fileflow/folder_picker"
    private val watcherChannel = "fileflow/file_watcher"
    private val watcherEventsChannel = "fileflow/file_watcher_events"
    private val videoThumbChannel = "fileflow/video_thumb"
    private val monitorChannel = "fileflow/monitor"
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, videoThumbChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getThumbnail") {
                    val path = call.argument<String>("path")
                    val maxWidth = call.argument<Int>("maxWidth") ?: 320
                    if (path == null) {
                        result.success(null)
                    } else {
                        VideoThumbnailer.generate(path, maxWidth) { bytes ->
                            mainHandler.post { result.success(bytes) }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Background monitoring foreground service control.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, monitorChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        MonitorService.start(applicationContext)
                        result.success(null)
                    }
                    "stop" -> {
                        MonitorService.stop(applicationContext)
                        result.success(null)
                    }
                    "isBatteryExempt" -> result.success(isBatteryExempt())
                    "requestBatteryExemption" -> {
                        requestBatteryExemption()
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

    override fun onResume() {
        super.onResume()
        // App is visible: the in-app popup handles arrivals, so the background
        // service stands down to avoid duplicate prompts.
        AppState.isForeground = true
    }

    override fun onPause() {
        AppState.isForeground = false
        super.onPause()
    }

    private fun isBatteryExempt(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    @Suppress("BatteryLife")
    private fun requestBatteryExemption() {
        if (isBatteryExempt()) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName")),
            )
        } catch (_: Exception) {
            // Some devices lack this screen; the ongoing service still runs.
        }
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
