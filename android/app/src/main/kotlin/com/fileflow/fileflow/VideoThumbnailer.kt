package com.fileflow.fileflow

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Generates a JPEG thumbnail for a video file using Android's
 * [MediaMetadataRetriever]. Runs off the main thread; replies via [onResult]
 * which is always invoked with the bytes (or null on failure).
 *
 * Self-contained — no third-party plugin — so it has no AGP/namespace issues.
 */
object VideoThumbnailer {
    private val executor = Executors.newFixedThreadPool(2)

    fun generate(path: String, maxWidth: Int, onResult: (ByteArray?) -> Unit) {
        executor.execute {
            onResult(runCatching { extract(path, maxWidth) }.getOrNull())
        }
    }

    private fun extract(path: String, maxWidth: Int): ByteArray? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            var frame = retriever.getFrameAtTime(
                0,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            ) ?: retriever.frameAtTime ?: return null

            if (frame.width > maxWidth && frame.width > 0) {
                val ratio = maxWidth.toFloat() / frame.width
                val height = (frame.height * ratio).toInt().coerceAtLeast(1)
                frame = Bitmap.createScaledBitmap(frame, maxWidth, height, true)
            }

            val stream = ByteArrayOutputStream()
            frame.compress(Bitmap.CompressFormat.JPEG, 60, stream)
            return stream.toByteArray()
        } finally {
            retriever.release()
        }
    }
}
