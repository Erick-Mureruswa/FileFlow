import 'package:flutter/services.dart';

/// Generates a JPEG thumbnail for a video via the native MediaMetadataRetriever
/// (see VideoThumbnailer.kt). Returns null if generation fails.
class VideoThumbnailService {
  static const _channel = MethodChannel('fileflow/video_thumb');

  static Future<Uint8List?> generate(String path, {int maxWidth = 320}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('getThumbnail', {
        'path': path,
        'maxWidth': maxWidth,
      });
    } on PlatformException {
      return null;
    }
  }
}
