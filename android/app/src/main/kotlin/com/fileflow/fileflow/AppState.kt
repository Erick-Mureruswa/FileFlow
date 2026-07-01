package com.fileflow.fileflow

/**
 * Shared in-process flag. When the app UI is in the foreground, the in-app Dart
 * watcher shows the interactive arrival popup, so the background service skips
 * its own detection to avoid duplicate work and duplicate prompts.
 */
object AppState {
    @Volatile
    @JvmStatic
    var isForeground: Boolean = false
}
