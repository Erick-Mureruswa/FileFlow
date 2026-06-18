import 'package:fileflow/core/models/tracked_file.dart';

class FileUtils {
  FileUtils._();

  static FileType detectType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (_imageExtensions.contains(ext)) return FileType.image;
    if (_videoExtensions.contains(ext)) return FileType.video;
    if (_documentExtensions.contains(ext)) return FileType.document;
    if (_audioExtensions.contains(ext)) return FileType.audio;
    if (_archiveExtensions.contains(ext)) return FileType.archive;
    return FileType.other;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatExpiry(DateTime? expiresAt) {
    if (expiresAt == null) return 'Never expires';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inMinutes < 60) return 'Expires in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Expires in ${diff.inHours}h';
    if (diff.inDays == 1) return 'Expires tomorrow';
    return 'Expires in ${diff.inDays} days';
  }

  static const _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'avif', 'tiff',
  };

  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'm4v',
  };

  static const _documentExtensions = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'odt',
    'ods', 'odp', 'rtf', 'md',
  };

  static const _audioExtensions = {
    'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'wma', 'opus',
  };

  static const _archiveExtensions = {
    'zip', 'rar', 'tar', 'gz', '7z', 'bz2', 'xz',
  };
}
