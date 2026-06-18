import 'package:fileflow/core/models/tracked_file.dart';

/// Describes a file that just arrived in a monitored folder and was tracked.
/// Used to drive the smart arrival popup.
class FileArrival {
  const FileArrival({
    required this.fileId,
    required this.name,
    required this.folderName,
    required this.path,
    required this.fileType,
  });

  final int fileId;
  final String name;
  final String folderName;
  final String path;
  final FileType fileType;
}
